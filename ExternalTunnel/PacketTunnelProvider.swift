import NetworkExtension

/// Túnel local de Nixel External.
/// No pretende ser un VPN comercial ni un proxy remoto: crea la interfaz local
/// que usa el modo Hybrid para coordinar la comunicación con la app.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let interfaceAddress = "10.7.1.1"
    private let peerAddress = "10.7.0.1"
    private var acceptingPackets = false

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let configured = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration as? [String: Any]
        let iface = Self.address(from: configured?["TunnelIfaceIP"] as? String) ?? interfaceAddress
        let peer = Self.address(from: configured?["TunnelPeerIP"] as? String) ?? peerAddress

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: peer)
        let ipv4 = NEIPv4Settings(addresses: [iface], subnetMasks: ["255.255.255.255"])
        // El destino debe ser el peer del túnel. La ruta anterior apuntaba a
        // la propia interfaz y no podía alcanzar ningún servicio AirLift/RSD.
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: peer, subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])
        setTunnelNetworkSettings(settings) { error in
            if let error {
                completionHandler(error)
                return
            }
            // External mantiene el packet flow activo después de configurar
            // la interfaz. Sin este loop iOS muestra la VPN como conectada,
            // pero el flujo queda vacío y Remote Pairing acaba en NOC 65669.
            self.acceptingPackets = true
            self.ext_readLoop()
            completionHandler(nil)
        }
    }

    /// Mantiene drenado el flujo local y devuelve los paquetes al flujo, igual
    /// que el read loop observable en la extensión External de referencia.
    /// El backend RPairing vive en la app; esta extensión no inventa un peer
    /// remoto ni afirma que el handshake haya terminado.
    private func ext_readLoop() {
        guard acceptingPackets else { return }
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, self.acceptingPackets else { return }
            if !packets.isEmpty {
                self.packetFlow.writePackets(packets, withProtocols: protocols)
            }
            self.ext_readLoop()
        }
    }

    private static func address(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.split(separator: "/", maxSplits: 1).first.map(String.init)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        acceptingPackets = false
        completionHandler()
    }
}
