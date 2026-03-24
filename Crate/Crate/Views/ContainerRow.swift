import SwiftUI

struct ContainerRow: View {
    let container: ManagedContainer
    var manager: CrateManager
    @State private var showTerminal = false
    @State private var showDetail = false
    @State private var terminalSession = ContainerTerminalSession()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: container.status.icon)
                .foregroundStyle(container.status.color)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.headline)
                Text(container.imageRef)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(container.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(container.status.color)
                Text(container.uptime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let ip = container.ipAddress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ip.split(separator: "/").first.map(String.init) ?? ip)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if !container.portMappings.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(container.portMappings) { mapping in
                                Text(":\(mapping.hostPort)→:\(mapping.containerPort)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 4) {
                Text("\(container.cpus) CPU")
                Text("\(container.memoryMB) MB")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .trailing)

            HStack(spacing: 6) {
                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Details & Settings")

                if container.status == .running {
                    Button {
                        showTerminal = true
                        if !terminalSession.isActive, let lc = container.container {
                            TerminalSessionStore.shared.sessions[container.id] = terminalSession
                            Task { await terminalSession.attach(to: lc) }
                        }
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .help("Terminal")

                    Button {
                        Task { await manager.stopContainer(id: container.id) }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop")
                }

                if container.status == .running || container.status == .stopped {
                    Button {
                        Task { await manager.restartContainer(id: container.id) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(container.status == .stopped ? "Start" : "Restart")
                }

                Button(role: .destructive) {
                    Task { await manager.deleteContainer(id: container.id) }
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showTerminal) {
            TerminalView(session: terminalSession, containerName: container.name, containerID: container.id)
                .frame(minWidth: 800, minHeight: 500)
        }
        .sheet(isPresented: $showDetail) {
            ContainerDetailView(containerID: container.id, manager: manager)
        }
    }
}
