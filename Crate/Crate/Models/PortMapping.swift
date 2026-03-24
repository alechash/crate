import Foundation

struct PortMapping: Identifiable, Equatable {
    let id = UUID()
    var hostPort: UInt16
    var containerPort: UInt16

    var description: String {
        "\(hostPort) → \(containerPort)"
    }
}
