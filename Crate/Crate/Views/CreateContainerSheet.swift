import SwiftUI

struct CreateContainerSheet: View {
    var manager: CrateManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var imageRef = "docker.io/library/alpine:latest"
    @State private var cpus: Double = 2
    @State private var memoryMB: Double = 1024
    @State private var commands: [String] = ["sleep infinity"]
    @State private var isCreating = false

    // Network settings
    @State private var enableNetworking = true
    @State private var hostname = ""
    @State private var customDNS = false
    @State private var dnsServer1 = "8.8.8.8"
    @State private var dnsServer2 = "8.8.4.4"

    // Port mappings
    @State private var portMappings: [PortMapping] = []
    @State private var newHostPort = ""
    @State private var newContainerPort = ""

    // Volumes
    @State private var volumeAttachments: [(volumeID: String, mountPath: String)] = []
    @State private var selectedVolumeID: String?
    @State private var volumeMountPath = "/data"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Container")
                    .font(.title2.bold())
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

            Form {
                if !manager.managerReady {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            if manager.isInitializing {
                                Text("Container runtime is starting up...")
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Container runtime is not available")
                                        .font(.headline)
                                    Text("Run `container system start` in Terminal, then relaunch Crate.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Image") {
                    Picker("Base Image", selection: $imageRef) {
                        ForEach(defaultImages) { entry in
                            Text(entry.reference).tag(entry.reference)
                        }
                        if !manager.images.isEmpty {
                            Divider()
                            ForEach(manager.images) { image in
                                if !defaultImages.contains(where: { $0.reference == image.reference }) {
                                    Text(image.reference).tag(image.reference)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Or enter a custom image reference", text: $imageRef)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                Section("General") {
                    TextField("Container name (auto-generated if empty)", text: $name)
                }

                Section {
                    ForEach(commands.indices, id: \.self) { index in
                        HStack {
                            TextField("Command", text: $commands[index])
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            if commands.count > 1 {
                                Button {
                                    commands.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        commands.append("")
                    } label: {
                        Label("Add Command", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Commands")
                } footer: {
                    Text("Multiple commands run concurrently. At least one long-running command (e.g. sleep infinity) is needed to keep the container alive.")
                        .font(.caption)
                }

                Section("Resources") {
                    LabeledContent("CPUs: \(Int(cpus))") {
                        Slider(value: $cpus, in: 1...16, step: 1)
                    }

                    LabeledContent("Memory: \(Int(memoryMB)) MB") {
                        Slider(value: $memoryMB, in: 256...16384, step: 256)
                    }
                }

                Section("Network") {
                    Toggle("Enable Networking", isOn: $enableNetworking)

                    if enableNetworking {
                        TextField("Hostname (optional)", text: $hostname)

                        Toggle("Custom DNS Servers", isOn: $customDNS)

                        if customDNS {
                            TextField("Primary DNS", text: $dnsServer1)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            TextField("Secondary DNS (optional)", text: $dnsServer2)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                if enableNetworking {
                    Section {
                        ForEach(portMappings) { mapping in
                            HStack(spacing: 6) {
                                Text("\(String(mapping.hostPort))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 60, alignment: .trailing)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text("\(String(mapping.containerPort))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 60, alignment: .leading)
                                Spacer()
                                Button {
                                    portMappings.removeAll { $0.id == mapping.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Host port", text: $newHostPort)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            TextField("Container port", text: $newContainerPort)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button("Add") {
                                addPortMapping()
                            }
                            .disabled(!canAddPort)
                        }
                    } header: {
                        Text("Port Forwarding")
                    } footer: {
                        Text("Map a port on your Mac (host) to a port inside the container.")
                            .font(.caption)
                    }
                }

                Section {
                    if volumeAttachments.isEmpty {
                        Text("No volumes attached")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(volumeAttachments.enumerated()), id: \.offset) { idx, attachment in
                            HStack {
                                if let vol = manager.volumes.first(where: { $0.id == attachment.volumeID }) {
                                    Text(vol.name)
                                        .font(.headline)
                                }
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(attachment.mountPath)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    volumeAttachments.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !availableVolumes.isEmpty {
                        HStack(spacing: 8) {
                            Picker("Volume", selection: $selectedVolumeID) {
                                Text("Select...").tag(nil as String?)
                                ForEach(availableVolumes) { vol in
                                    Text("\(vol.name) (\(vol.formattedSize))").tag(vol.id as String?)
                                }
                            }
                            .frame(width: 200)

                            TextField("Mount path", text: $volumeMountPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Button("Attach") {
                                attachVolume()
                            }
                            .disabled(selectedVolumeID == nil || volumeMountPath.isEmpty)
                        }
                    }
                } header: {
                    Text("Volumes")
                } footer: {
                    Text("Attach persistent volumes to store data that survives container restarts.")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: createContainer) {
                    if isCreating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating...")
                        }
                    } else {
                        Text("Create & Start")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(imageRef.isEmpty || isCreating || !manager.managerReady)
            }
            .padding()
        }
        .frame(width: 550, height: 850)
    }

    private var canAddPort: Bool {
        guard let hp = UInt16(newHostPort), let cp = UInt16(newContainerPort) else { return false }
        return hp > 0 && cp > 0 && !portMappings.contains(where: { $0.hostPort == hp })
    }

    private func addPortMapping() {
        guard let hp = UInt16(newHostPort), let cp = UInt16(newContainerPort) else { return }
        portMappings.append(PortMapping(hostPort: hp, containerPort: cp))
        newHostPort = ""
        newContainerPort = ""
    }

    private var availableVolumes: [CrateVolume] {
        manager.volumes.filter { vol in
            vol.attachedTo == nil && !volumeAttachments.contains(where: { $0.volumeID == vol.id })
        }
    }

    /// Validate and normalize a container volume mount path.
    /// - Parameter rawPath: The user-supplied mount path.
    /// - Returns: A sanitized absolute path, or `nil` if the path is invalid.
    private func sanitizedMountPath(from rawPath: String) -> String? {
        // Trim surrounding whitespace/newlines
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Require an absolute path
        guard trimmed.hasPrefix("/") else { return nil }

        // Disallow spaces in the path to avoid ambiguous or invalid mount points
        guard !trimmed.contains(" ") else { return nil }

        // Disallow parent-directory components
        let components = trimmed.split(separator: "/")
        guard !components.contains("..") else { return nil }

        // Disallow mounting at root or critical system paths
        let blocked = ["/", "/proc", "/sys", "/dev", "/run"]
        guard !blocked.contains(trimmed) else { return nil }

        return trimmed
    }

    private func attachVolume() {
        guard let volID = selectedVolumeID else { return }
        guard let mountPath = sanitizedMountPath(from: volumeMountPath) else { return }
        volumeAttachments.append((volumeID: volID, mountPath: mountPath))
        selectedVolumeID = nil
        volumeMountPath = "/data"
    }

    private func createContainer() {
        isCreating = true
        var dnsServers: [String] = []
        if enableNetworking && customDNS {
            if !dnsServer1.isEmpty { dnsServers.append(dnsServer1) }
            if !dnsServer2.isEmpty { dnsServers.append(dnsServer2) }
        }
        let volAttachments = volumeAttachments.map {
            CrateManager.VolumeAttachment(volumeID: $0.volumeID, mountPath: $0.mountPath)
        }
        Task {
            await manager.createAndStartContainer(
                name: name,
                imageRef: imageRef,
                cpus: Int(cpus),
                memoryMB: UInt64(memoryMB),
                commands: commands,
                enableNetworking: enableNetworking,
                dnsServers: dnsServers,
                hostname: hostname,
                portMappings: portMappings,
                volumeAttachments: volAttachments
            )
            isCreating = false
            dismiss()
        }
    }
}
