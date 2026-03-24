import SwiftUI

struct ContainerDetailView: View {
    let containerID: String
    var manager: CrateManager
    @Environment(\.dismiss) private var dismiss

    @State private var newHostPort = ""
    @State private var newContainerPort = ""

    private var container: ManagedContainer? {
        manager.containers.first { $0.id == containerID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let container {
                    Image(systemName: container.status.icon)
                        .foregroundStyle(container.status.color)
                        .font(.title3)
                    Text(container.name)
                        .font(.title2.bold())
                } else {
                    Text("Container")
                        .font(.title2.bold())
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if let container {
                Form {
                    Section("Details") {
                        LabeledContent("ID", value: container.id)
                            .textSelection(.enabled)
                        LabeledContent("Image", value: container.imageRef)
                            .textSelection(.enabled)
                        LabeledContent("Status") {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(container.status.color)
                                    .frame(width: 8, height: 8)
                                Text(container.status.rawValue.capitalized)
                            }
                        }
                        LabeledContent("Uptime", value: container.uptime)
                    }

                    Section("Resources") {
                        LabeledContent("CPUs", value: "\(container.cpus)")
                        LabeledContent("Memory", value: "\(container.memoryMB) MB")
                    }

                    Section("Network") {
                        if let ip = container.ipAddress {
                            LabeledContent("IP Address") {
                                Text(ip.split(separator: "/").first.map(String.init) ?? ip)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        } else {
                            LabeledContent("Network", value: "Disabled")
                        }
                    }

                    if container.ipAddress != nil {
                        Section {
                            if container.portMappings.isEmpty {
                                Text("No port forwarding configured")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(container.portMappings) { mapping in
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text("localhost:\(mapping.hostPort)")
                                                .font(.system(.body, design: .monospaced))
                                            Image(systemName: "arrow.right")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                            Text("container:\(mapping.containerPort)")
                                                .font(.system(.body, design: .monospaced))
                                        }

                                        Spacer()

                                        if container.status == .running {
                                            Button {
                                                manager.removePortForward(containerID: containerID, mappingID: mapping.id)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if container.status == .running {
                                HStack(spacing: 8) {
                                    TextField("Host", text: $newHostPort)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 80)
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                    TextField("Container", text: $newContainerPort)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 100)
                                    Button("Add") {
                                        addPort()
                                    }
                                    .disabled(!canAddPort)
                                }
                            }
                        } header: {
                            Text("Port Forwarding")
                        } footer: {
                            if container.status == .running {
                                Text("Add or remove port forwards on the fly while the container is running.")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView("Container Not Found", systemImage: "shippingbox")
            }
        }
        .frame(width: 500, height: 550)
    }

    private var canAddPort: Bool {
        guard let container else { return false }
        guard let hp = UInt16(newHostPort), let cp = UInt16(newContainerPort) else { return false }
        return hp > 0 && cp > 0 && !container.portMappings.contains(where: { $0.hostPort == hp })
    }

    private func addPort() {
        guard let hp = UInt16(newHostPort), let cp = UInt16(newContainerPort) else { return }
        manager.addPortForward(containerID: containerID, hostPort: hp, containerPort: cp)
        newHostPort = ""
        newContainerPort = ""
    }
}
