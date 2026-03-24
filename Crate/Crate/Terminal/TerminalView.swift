import SwiftUI

struct TerminalView: View {
    var session: ContainerTerminalSession
    let containerName: String
    var containerID: String = ""
    @State private var inputText = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int? = nil
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.green)
                Text(containerName)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                    Text(session.workingDirectory)
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())

                Spacer()

                if session.isActive {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    session.clearScreen()
                } label: {
                    Image(systemName: "trash.square")
                }
                .help("Clear terminal")
                .buttonStyle(.borderless)

                Button {
                    TerminalSessionStore.shared.sessions[containerID] = session
                    openWindow(id: "terminal", value: containerID)
                    dismiss()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Pop out to window")
                .buttonStyle(.borderless)
                .disabled(containerID.isEmpty)

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if session.lines.isEmpty && session.isActive {
                            Text("Connecting...")
                                .foregroundStyle(Color(white: 0.5))
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                        }
                        ForEach(session.lines) { line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(white: 0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                .onChange(of: session.scrollToken) {
                    if let last = session.lines.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            HStack(spacing: 6) {
                Text(session.workingDirectory.split(separator: "/").last.map(String.init) ?? "/")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))
                Text("$")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.green)

                TextField("", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)
                    .focused($inputFocused)
                    .onSubmit { sendInput() }
                    .onKeyPress(.upArrow) {
                        navigateHistory(direction: .up)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        navigateHistory(direction: .down)
                        return .handled
                    }
                    .onKeyPress(characters: .init(charactersIn: "c")) { press in
                        if press.modifiers.contains(.control) {
                            session.sendControlC()
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(characters: .init(charactersIn: "d")) { press in
                        if press.modifiers.contains(.control) {
                            session.sendControlD()
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(characters: .init(charactersIn: "l")) { press in
                        if press.modifiers.contains(.control) {
                            session.clearScreen()
                            return .handled
                        }
                        return .ignored
                    }
                    .disabled(!session.isActive)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        }
        .onAppear { inputFocused = true }
    }

    private func sendInput() {
        let cmd = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""
        historyIndex = nil

        if !cmd.isEmpty {
            commandHistory.append(cmd)
        }

        if cmd == "clear" {
            session.clearScreen()
            session.send(cmd + "\n")
            return
        }

        session.sendCommand(cmd)
    }

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        switch direction {
        case .up:
            if let idx = historyIndex {
                historyIndex = max(0, idx - 1)
            } else {
                historyIndex = commandHistory.count - 1
            }
        case .down:
            if let idx = historyIndex {
                if idx < commandHistory.count - 1 {
                    historyIndex = idx + 1
                } else {
                    historyIndex = nil
                    inputText = ""
                    return
                }
            }
        }
        if let idx = historyIndex {
            inputText = commandHistory[idx]
        }
    }
}

struct PopoutTerminalHost: View {
    let containerID: String
    @State private var session: ContainerTerminalSession?

    var body: some View {
        Group {
            if let session {
                TerminalView(session: session, containerName: containerID, containerID: containerID)
            } else {
                ContentUnavailableView("Terminal session not found", systemImage: "terminal")
            }
        }
        .onAppear {
            session = TerminalSessionStore.shared.sessions[containerID]
        }
    }
}
