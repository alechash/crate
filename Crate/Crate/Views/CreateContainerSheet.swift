import SwiftUI

struct CreateContainerSheet: View {
    var manager: CrateManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var imageRef = "docker.io/library/alpine:latest"
    @State private var cpus: Double = 2
    @State private var memoryMB: Double = 1024
    @State private var command = "sleep infinity"
    @State private var isCreating = false

    // Network settings
    @State private var enableNetworking = true
    @State private var hostname = ""
    @State private var customDNS = false
    @State private var dnsServer1 = "8.8.8.8"
    @State private var dnsServer2 = "8.8.4.4"

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
                    TextField("Command", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
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
        .frame(width: 550, height: 650)
    }

    private func createContainer() {
        isCreating = true
        let args = command.split(separator: " ").map(String.init)
        var dnsServers: [String] = []
        if enableNetworking && customDNS {
            if !dnsServer1.isEmpty { dnsServers.append(dnsServer1) }
            if !dnsServer2.isEmpty { dnsServers.append(dnsServer2) }
        }
        Task {
            await manager.createAndStartContainer(
                name: name,
                imageRef: imageRef,
                cpus: Int(cpus),
                memoryMB: UInt64(memoryMB),
                command: args,
                enableNetworking: enableNetworking,
                dnsServers: dnsServers,
                hostname: hostname
            )
            isCreating = false
            dismiss()
        }
    }
}
