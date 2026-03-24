import Foundation

struct ManagedImage: Identifiable {
    let id: String
    let reference: String
    let digest: String
    let mediaType: String

    var shortDigest: String {
        String(digest.prefix(19))
    }
}
