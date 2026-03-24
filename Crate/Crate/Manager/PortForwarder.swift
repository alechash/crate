import Foundation
import Network

/// Forwards TCP traffic from localhost:hostPort to containerIP:containerPort.
final class PortForwarder: @unchecked Sendable {
    let hostPort: UInt16
    let containerPort: UInt16
    let containerIP: String
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.crate.portforward")

    init(hostPort: UInt16, containerPort: UInt16, containerIP: String) {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.containerIP = containerIP
    }

    func start() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: hostPort)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] inbound in
            self?.handleConnection(inbound)
        }

        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("PortForwarder listener failed: \(error)")
            }
        }

        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ inbound: NWConnection) {
        let ip = containerIP.split(separator: "/").first.map(String.init) ?? containerIP
        let outbound = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(rawValue: containerPort)!,
            using: .tcp
        )

        inbound.start(queue: queue)
        outbound.start(queue: queue)

        outbound.stateUpdateHandler = { state in
            switch state {
            case .ready:
                Self.relay(from: inbound, to: outbound)
                Self.relay(from: outbound, to: inbound)
            case .failed:
                inbound.cancel()
            default:
                break
            }
        }
    }

    private static func relay(from source: NWConnection, to destination: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                destination.send(content: data, completion: .contentProcessed { _ in
                    if !isComplete {
                        relay(from: source, to: destination)
                    }
                })
            }
            if isComplete || error != nil {
                destination.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                    destination.cancel()
                })
                source.cancel()
            }
        }
    }
}
