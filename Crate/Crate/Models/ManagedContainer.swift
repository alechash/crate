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
    var volumeAttachments: [(volumeID: String, mountPath: String)]
    var processArgs: [String]
    var cpus: Int
    var memoryMB: UInt64
    var container: LinuxContainer?

    struct Persisted: Codable {
        let id: String
        let name: String
        let imageRef: String
        let status: String
        let ipAddress: String?
        let portMappings: [PersistedPortMapping]
        let volumeAttachments: [PersistedVolumeAttachment]
        let processArgs: [String]
        let cpus: Int
        let memoryMB: UInt64
    }

    struct PersistedPortMapping: Codable {
        let hostPort: UInt16
        let containerPort: UInt16
    }

    struct PersistedVolumeAttachment: Codable {
        let volumeID: String
        let mountPath: String
    }

    func toPersisted() -> Persisted {
        Persisted(
            id: id,
            name: name,
            imageRef: imageRef,
            status: status.rawValue,
            ipAddress: ipAddress,
            portMappings: portMappings.map { PersistedPortMapping(hostPort: $0.hostPort, containerPort: $0.containerPort) },
            volumeAttachments: volumeAttachments.map { PersistedVolumeAttachment(volumeID: $0.volumeID, mountPath: $0.mountPath) },
            processArgs: processArgs,
            cpus: cpus,
            memoryMB: memoryMB
        )
    }

    static func fromPersisted(_ p: Persisted) -> ManagedContainer {
        ManagedContainer(
            id: p.id,
            name: p.name,
            imageRef: p.imageRef,
            status: Status(rawValue: p.status) ?? .stopped,
            uptime: "Stopped",
            ipAddress: p.ipAddress,
            portMappings: p.portMappings.map { PortMapping(hostPort: $0.hostPort, containerPort: $0.containerPort) },
            portForwarders: [],
            volumeAttachments: p.volumeAttachments.map { ($0.volumeID, $0.mountPath) },
            processArgs: p.processArgs,
            cpus: p.cpus,
            memoryMB: p.memoryMB,
            container: nil
        )
    }
}
