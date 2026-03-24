import SwiftUI
import Containerization

struct ManagedContainer: Identifiable {
    enum Status: String {
        case running, stopped, error

        var color: Color {
            switch self {
            case .running: .green
            case .stopped: .gray
            case .error: .red
            }
        }

        var icon: String {
            switch self {
            case .running: "circle.fill"
            case .stopped: "circle"
            case .error: "exclamationmark.circle.fill"
            }
        }
    }

    let id: String
    let name: String
    let imageRef: String
    var status: Status
    var uptime: String
    var ipAddress: String?
    var portMappings: [PortMapping]
    var portForwarders: [PortForwarder]
    var cpus: Int
    var memoryMB: UInt64
    var container: LinuxContainer?
}
