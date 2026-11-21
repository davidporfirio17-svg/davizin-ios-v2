import Foundation

enum EmbeddedResource: String, CaseIterable {
    case clothingCatalog = "asset_catalog.json"
    case splashVideo = "splash_media.mp4"
    case activationSound = "notify_tone.mp3"
    case loginBackground = "bg_visual.mp4"
}

final class EmbeddedResources {
    static let shared = EmbeddedResources()

    private var cacheDir: String?
    private static let lock = NSLock()
    private static var extracted = false

    private static let xorKey: [UInt8] = Array("com.apple.containermanagerd.internal.db".utf8)

    func url(for resource: EmbeddedResource) -> URL? {
        ensureExtracted()
        if let dir = cacheDir {
            let path = (dir as NSString).appendingPathComponent(resource.rawValue)
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        let name = (resource.rawValue as NSString).deletingPathExtension
        let ext = (resource.rawValue as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    func data(for resource: EmbeddedResource) -> Data? {
        guard let u = url(for: resource) else { return nil }
        return try? Data(contentsOf: u)
    }

    private func ensureExtracted() {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        if Self.extracted { return }

        guard let cacheURL = Bundle.main.url(forResource: "runtime", withExtension: "cache"),
              let packed = try? Data(contentsOf: cacheURL) else { return }

        let dir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let resDir = (dir as NSString).appendingPathComponent("_sys")

        let marker = (resDir as NSString).appendingPathComponent(EmbeddedResource.activationSound.rawValue)
        if FileManager.default.fileExists(atPath: marker) {
            cacheDir = resDir
            Self.extracted = true
            return
        }

        try? FileManager.default.createDirectory(atPath: resDir, withIntermediateDirectories: true)
        if unpack(data: packed, to: resDir) {
            cacheDir = resDir
            Self.extracted = true
        }
    }

    private func unpack(data: Data, to dir: String) -> Bool {
        let bytes = [UInt8](data)
        let count = bytes.count
        guard count >= 8,
              bytes[0] == 0x4E, bytes[1] == 0x58,
              bytes[2] == 0x52, bytes[3] == 0x43 else { return false }

        let numEntries = Int(bytes[4]) | (Int(bytes[5]) << 8) |
                         (Int(bytes[6]) << 16) | (Int(bytes[7]) << 24)
        var offset = 8
        let key = Self.xorKey
        let keyLen = key.count

        for _ in 0..<numEntries {
            guard offset + 4 <= count else { return false }
            let nameLen = Int(bytes[offset]) | (Int(bytes[offset+1]) << 8) |
                          (Int(bytes[offset+2]) << 16) | (Int(bytes[offset+3]) << 24)
            offset += 4
            guard offset + nameLen <= count else { return false }
            guard let name = String(bytes: bytes[offset..<offset+nameLen], encoding: .utf8) else { return false }
            offset += nameLen

            guard offset + 4 <= count else { return false }
            let dataLen = Int(bytes[offset]) | (Int(bytes[offset+1]) << 8) |
                          (Int(bytes[offset+2]) << 16) | (Int(bytes[offset+3]) << 24)
            offset += 4
            guard offset + dataLen <= count else { return false }

            var fileData = [UInt8](bytes[offset..<offset+dataLen])
            for i in 0..<fileData.count {
                fileData[i] ^= key[i % keyLen]
            }
            offset += dataLen

            let filePath = (dir as NSString).appendingPathComponent(name)
            try? Data(fileData).write(to: URL(fileURLWithPath: filePath))
        }
        return true
    }
}
