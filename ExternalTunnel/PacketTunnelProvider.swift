import NetworkExtension

/// Túnel local de Nixel External.
/// No pretende ser un VPN comercial ni un proxy remoto: crea la interfaz local
/// que usa el modo Hybrid para coordinar la comunicación con la app.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let interfaceAddress = "10.7.1.1"
    private let peerAddress = "10.7.0.1"

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: peerAddress)
        let ipv4 = NEIPv4Settings(addresses: [interfaceAddress], subnetMasks: ["255.255.255.255"])
        // Solo se anuncia la ruta local del túnel. No se secuestra el tráfico
        // general del teléfono ni se deja el dispositivo sin internet.
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: interfaceAddress, subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])
        setTunnelNetworkSettings(settings) { error in
            if let error {
                completionHandler(error)
                return
            }
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
