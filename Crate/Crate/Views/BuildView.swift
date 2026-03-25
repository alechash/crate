import SwiftUI

struct BuildView: View {
    var manager: CrateManager

    @State private var contextDir: URL?
    @State private var dockerfilePath: URL?
    @State private var useCustomDockerfile = false
    @State private var tag = ""
    @State private var noCache = false

    // Build args
    @State private var buildArgs: [(key: String, value: String)] = []
    @State private var newArgKey = ""
    @State private var newArgValue = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Build Context") {
                    HStack {
                        if let dir = contextDir {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(dir.path(percentEncoded: false))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("No directory selected")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Choose...") {
                            chooseContextDir()
                        }
                    }

                    Toggle("Custom Dockerfile path", isOn: $useCustomDockerfile)

                    if useCustomDockerfile {
                        HStack {
                            if let path = dockerfilePath {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.orange)
                                Text(path.path(percentEncoded: false))
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } else {
                                Text("No file selected")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Choose...") {
                                chooseDockerfile()
                            }
                        }
                    }
                }

                Section("Image Tag") {
                    TextField("e.g. my-app:latest", text: $tag)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    ForEach(Array(buildArgs.enumerated()), id: \.offset) { idx, arg in
                        HStack {
                            Text("\(arg.key)=\(arg.value)")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                buildArgs.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Key", text: $newArgKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Text("=")
                            .foregroundStyle(.secondary)
                        TextField("Value", text: $newArgValue)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Add") {
                            addBuildArg()
                        }
                        .disabled(newArgKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Build Arguments")
                } footer: {
                    Text("Set build-time variables accessible via ARG in the Dockerfile.")
                        .font(.caption)
                }

                Section("Options") {
                    Toggle("No cache", isOn: $noCache)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Build output
            if manager.isBuilding || !manager.buildOutput.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Build Output")
                            .font(.headline)
                        Spacer()
                        if manager.isBuilding {
                            ProgressView()
                                .controlSize(.small)
                        }
                        if !manager.buildOutput.isEmpty {
                            Button("Clear") {
                                manager.buildOutput = ""
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    ScrollView {
                        Text(manager.buildOutput.isEmpty ? "Building..." : manager.buildOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(manager.buildOutput.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 250)
                    .background(.black.opacity(0.03))
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(action: startBuild) {
                    if manager.isBuilding {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Building...")
                        }
                    } else {
                        Label("Build Image", systemImage: "hammer.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canBuild)
            }
            .padding()
        }
        .navigationTitle("Build")
    }

    private var canBuild: Bool {
        !manager.isBuilding
        && contextDir != nil
        && !tag.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addBuildArg() {
        let key = newArgKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        buildArgs.append((key: key, value: newArgValue))
        newArgKey = ""
        newArgValue = ""
    }

    private func chooseContextDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the build context directory"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            contextDir = panel.url
        }
    }

    private func chooseDockerfile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .data]
        panel.message = "Select a Dockerfile or Containerfile"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            dockerfilePath = panel.url
        }
    }

    private func startBuild() {
        let dir = contextDir!
        let dockerfile = useCustomDockerfile ? dockerfilePath : nil
        let args = buildArgs.map { "\($0.key)=\($0.value)" }
        let tagValue = tag.trimmingCharacters(in: .whitespaces)
        let noCacheValue = noCache

        Task {
            await manager.buildImage(
                contextDir: dir,
                dockerfilePath: dockerfile,
                tag: tagValue,
                buildArgs: args,
                noCache: noCacheValue
            )
        }
    }
}
