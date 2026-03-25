import SwiftUI

struct MenuBarView: View {
    var manager: CrateManager

    private var runningContainers: [ManagedContainer] {
        manager.containers.filter { $0.status == .running }
    }

    private var stoppedContainers: [ManagedContainer] {
        manager.containers.filter { $0.status != .running }
    }

    var body: some View {
        if manager.containers.isEmpty {
            Text("No Containers")
                .foregroundStyle(.secondary)
        } else {
            if !runningContainers.isEmpty {
                Section("Running") {
                    ForEach(runningContainers) { container in
                        MenuBarContainerItem(container: container, manager: manager)
                    }
                }
            }

            if !stoppedContainers.isEmpty {
                Section("Stopped") {
                    ForEach(stoppedContainers) { container in
                        MenuBarContainerItem(container: container, manager: manager)
                    }
                }
            }
        }

        Divider()

        HStack {
            Circle()
                .fill(manager.managerReady ? .green : .red)
                .frame(width: 6, height: 6)
            Text(manager.managerReady ? "Runtime Ready" : "Runtime Unavailable")
        }

        Divider()

        Button("Open Crate") {
            NSApplication.shared.activate()
            for window in NSApplication.shared.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        .keyboardShortcut("o")

        Button("Quit Crate") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

struct MenuBarContainerItem: View {
    let container: ManagedContainer
    var manager: CrateManager

    var body: some View {
        Menu {
            if container.status == .running {
                Button("Stop") {
                    Task { await manager.stopContainer(id: container.id) }
                }
                Button("Restart") {
                    Task { await manager.restartContainer(id: container.id) }
                }
            } else {
                Button("Start") {
                    Task { await manager.restartContainer(id: container.id) }
                }
            }

            if let ip = container.ipAddress {
                Divider()
                Text(ip.split(separator: "/").first.map(String.init) ?? ip)
            }

            if !container.portMappings.isEmpty {
                Divider()
                ForEach(container.portMappings) { mapping in
                    Text(":\(mapping.hostPort) \u{2192} :\(mapping.containerPort)")
                }
            }
        } label: {
            HStack {
                Image(systemName: container.status == .running ? "circle.fill" : "circle")
                    .foregroundStyle(container.status.color)
                    .font(.caption2)
                Text(container.name)
                Spacer()
                Text(container.imageRef.split(separator: "/").last.map(String.init) ?? container.imageRef)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}
