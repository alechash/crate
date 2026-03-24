import Foundation

struct CrateVolume: Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    var attachedTo: String?

    var hostPath: URL {
        CrateVolume.volumesRoot.appendingPathComponent(id)
    }

    var formattedSize: String {
        let bytes = (try? FileManager.default.allocatedSizeOfDirectory(at: hostPath)) ?? 0
        if bytes > 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes > 1_048_576 {
            return "\(bytes / 1_048_576) MB"
        } else if bytes > 1024 {
            return "\(bytes / 1024) KB"
        }
        return "Empty"
    }

    static let volumesRoot: URL = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.apple.container/volumes")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()
}

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        guard let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            total += UInt64(size)
        }
        return total
    }
}
