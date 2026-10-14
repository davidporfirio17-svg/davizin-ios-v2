import NetworkExtension
import Darwin

/// Túnel local para los endpoints RSD de AirLift (10.7.0.1–10.7.0.3).
/// Cada paquete IPv4 vuelve por el mismo túnel con origen y destino intercambiados.
///
/// Además expone un relay TCP interno en 127.0.0.1:49153 que, cuando el app
/// conecta ahí, abre un socket privilegiado desde el proceso de la extension
/// (que SÍ puede bind a 10.7.1.1 o IP_BOUND_IF al utun en iOS 27 celular) y
/// hace proxy al remotepairingd en 127.0.0.1:49152.  Así `remotepairingd` ve
/// un source IP no-loopback incluso cuando el app vive en datos celulares,
/// donde el kernel iOS 27 ignora las rutas /32 del VPN.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var interfaceAddress = "10.7.1.1"
    private var peerAddress = "10.7.0.1"
    private var relayListenerFd: Int32 = -1
    private var relayAcceptSource: DispatchSourceRead?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let config = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration ?? [:]
        if let value = config["TunnelIfaceIP"] as? String, let ip = value.split(separator: "/").first { interfaceAddress = String(ip) }
        if let value = config["TunnelPeerIP"] as? String, let ip = value.split(separator: "/").first { peerAddress = String(ip) }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: peerAddress)
        let ipv4 = NEIPv4Settings(addresses: [interfaceAddress], subnetMasks: ["255.255.255.255"])
        var loopbackHosts: Set<String> = ["10.7.0.1", "10.7.0.2", "10.7.0.3"]
        loopbackHosts.insert(peerAddress)
        ipv4.includedRoutes = loopbackHosts.sorted().map {
            NEIPv4Route(destinationAddress: $0, subnetMask: "255.255.255.255")
        }
        ipv4.excludedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { [weak self] error in
            if error == nil {
                self?.readLoop()
                self?.startAirliftRelay()
            }
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stopAirliftRelay()
        completionHandler()
    }

    private func readLoop() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            var out: [Data] = []
            for (index, packet) in packets.enumerated() {
                var data = packet
                if protocols[index].intValue == AF_INET, data.count >= 20 {
                    data.withUnsafeMutableBytes { raw in
                        let bytes = raw.bindMemory(to: UInt8.self)
                        for i in 0..<4 { bytes.swapAt(12 + i, 16 + i) }
                    }
                }
                out.append(data)
            }
            self.packetFlow.writePackets(out, withProtocols: protocols)
            self.readLoop()
        }
    }

    // MARK: - AirLift relay (celular)

    private func startAirliftRelay() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[AirliftRelay] socket() failed errno=%d", errno)
            return
        }
        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var listenAddr = sockaddr_in()
        listenAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        listenAddr.sin_family = sa_family_t(AF_INET)
        listenAddr.sin_port = UInt16(49153).bigEndian
        listenAddr.sin_addr.s_addr = UInt32(0x7F000001).bigEndian // 127.0.0.1

        let bindOk = withUnsafePointer(to: &listenAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                bind(fd, sap, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindOk == 0 else {
            NSLog("[AirliftRelay] bind 127.0.0.1:49153 failed errno=%d", errno)
            close(fd)
            return
        }
        guard listen(fd, 8) == 0 else {
            NSLog("[AirliftRelay] listen failed errno=%d", errno)
            close(fd)
            return
        }

        relayListenerFd = fd
        let queue = DispatchQueue(label: "airlift.relay.accept", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptAirliftRelayClient()
        }
        source.resume()
        relayAcceptSource = source
        NSLog("[AirliftRelay] listening on 127.0.0.1:49153")
    }

    private func stopAirliftRelay() {
        relayAcceptSource?.cancel()
        relayAcceptSource = nil
        if relayListenerFd >= 0 {
            close(relayListenerFd)
            relayListenerFd = -1
        }
    }

    private func acceptAirliftRelayClient() {
        guard relayListenerFd >= 0 else { return }
        var caddr = sockaddr_in()
        var clen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientFd: Int32 = withUnsafeMutablePointer(to: &caddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                accept(relayListenerFd, sap, &clen)
            }
        }
        if clientFd < 0 { return }
        NSLog("[AirliftRelay] inbound client accepted (fd=%d)", clientFd)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { close(clientFd); return }
            guard let outboundFd = self.openPrivilegedOutbound() else {
                NSLog("[AirliftRelay] outbound creation failed; closing client")
                close(clientFd)
                return
            }
            self.pumpBetween(clientFd: clientFd, outboundFd: outboundFd)
        }
    }

    /// Abre un socket desde el proceso de la extension hacia
    /// 127.0.0.1:49152 (remotepairingd) intentando primero `bind(10.7.1.1)` y
    /// luego `IP_BOUND_IF` al utun para que la source IP sea no-loopback.
    private func openPrivilegedOutbound() -> Int32? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }

        // Estrategia 1: bind al 10.7.1.1 (la extension OWNS esta IP)
        var baddr = sockaddr_in()
        baddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        baddr.sin_family = sa_family_t(AF_INET)
        baddr.sin_port = 0
        baddr.sin_addr.s_addr = UInt32(0x0A070101).bigEndian // 10.7.1.1
        let bindResult = withUnsafePointer(to: &baddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                bind(fd, sap, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if bindResult == 0 {
            NSLog("[AirliftRelay] outbound bind(10.7.1.1) OK")
        } else {
            NSLog("[AirliftRelay] bind(10.7.1.1) failed errno=%d; trying IP_BOUND_IF", errno)
            // Estrategia 2: IP_BOUND_IF al utun (encuentra el interfaz que tiene 10.7.1.1)
            if let idx = utunIfIndex() {
                var ifindex: UInt32 = idx
                let rc = setsockopt(fd, IPPROTO_IP, 25 /* IP_BOUND_IF */,
                                    &ifindex,
                                    socklen_t(MemoryLayout<UInt32>.size))
                if rc == 0 {
                    NSLog("[AirliftRelay] IP_BOUND_IF to utun idx=%u OK", idx)
                } else {
                    NSLog("[AirliftRelay] IP_BOUND_IF failed errno=%d", errno)
                }
            } else {
                NSLog("[AirliftRelay] utun ifindex not found")
            }
        }

        // Conectar a remotepairingd en 127.0.0.1:49152
        var daddr = sockaddr_in()
        daddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        daddr.sin_family = sa_family_t(AF_INET)
        daddr.sin_port = UInt16(49152).bigEndian
        daddr.sin_addr.s_addr = UInt32(0x7F000001).bigEndian // 127.0.0.1
        let connResult = withUnsafePointer(to: &daddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                connect(fd, sap, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connResult != 0 {
            NSLog("[AirliftRelay] connect(127.0.0.1:49152) failed errno=%d", errno)
            close(fd)
            return nil
        }
        NSLog("[AirliftRelay] outbound established to remotepairingd (fd=%d)", fd)
        return fd
    }

    private func utunIfIndex() -> UInt32? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let start = ifap else { return nil }
        defer { freeifaddrs(start) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let ifa = cursor {
            if let saPtr = ifa.pointee.ifa_addr,
               saPtr.pointee.sa_family == sa_family_t(AF_INET) {
                let sinPtr = UnsafeRawPointer(saPtr).assumingMemoryBound(to: sockaddr_in.self)
                let addrHostOrder = UInt32(bigEndian: sinPtr.pointee.sin_addr.s_addr)
                if addrHostOrder == 0x0A070101 { // 10.7.1.1
                    let idx = if_nametoindex(ifa.pointee.ifa_name)
                    if idx > 0 { return idx }
                }
            }
            cursor = ifa.pointee.ifa_next
        }
        return nil
    }

    private func pumpBetween(clientFd: Int32, outboundFd: Int32) {
        let qA = DispatchQueue(label: "airlift.relay.pump-a", qos: .userInitiated)
        let qB = DispatchQueue(label: "airlift.relay.pump-b", qos: .userInitiated)
        let closed = DispatchSemaphore(value: 1)
        var alreadyClosed = false
        let closeBoth: () -> Void = {
            closed.wait()
            if !alreadyClosed {
                alreadyClosed = true
                close(clientFd)
                close(outboundFd)
                NSLog("[AirliftRelay] relay pair closed (fds %d/%d)", clientFd, outboundFd)
            }
            closed.signal()
        }
        qA.async { Self.pumpOnce(from: clientFd, to: outboundFd, onEnd: closeBoth) }
        qB.async { Self.pumpOnce(from: outboundFd, to: clientFd, onEnd: closeBoth) }
    }

    private static func pumpOnce(from srcFd: Int32, to dstFd: Int32, onEnd: @escaping () -> Void) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = buffer.withUnsafeMutableBufferPointer { ptr in
                Darwin.read(srcFd, ptr.baseAddress, ptr.count)
            }
            if n <= 0 { onEnd(); return }
            var off = 0
            while off < n {
                let w = buffer.withUnsafeBufferPointer { ptr -> Int in
                    guard let base = ptr.baseAddress else { return -1 }
                    return Darwin.write(dstFd, base.advanced(by: off), n - off)
                }
                if w <= 0 { onEnd(); return }
                off += w
            }
        }
    }
}
