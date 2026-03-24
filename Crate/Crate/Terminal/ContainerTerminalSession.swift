import Foundation
import Containerization

@MainActor
final class TerminalSessionStore {
    static let shared = TerminalSessionStore()
    var sessions: [String: ContainerTerminalSession] = [:]
}

@MainActor
@Observable
final class ContainerTerminalSession {
    var lines: [TerminalLine] = []
    var isActive = false
    var scrollToken = UUID()
    var workingDirectory: String = "/"
    let inputReader = TerminalInputReader()

    private var currentLine = ""
    private var process: LinuxProcess?
    private var pendingPwdRead = false

    struct TerminalLine: Identifiable {
        let id = UUID()
        let text: String
    }

    func attach(to container: LinuxContainer) async {
        isActive = true
        lines = []
        currentLine = ""
        workingDirectory = "/"

        let writer = TerminalOutputWriter { [weak self] data in
            Task { @MainActor in
                self?.processOutput(data)
            }
        }

        do {
            let proc = try await container.exec(
                "shell-\(UUID().uuidString.prefix(6))"
            ) { config in
                config.arguments = ["/bin/sh"]
                config.environmentVariables = [
                    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                    "TERM=xterm-256color",
                    "HOME=/root",
                ]
                config.stdin = inputReader
                config.stdout = writer
                config.stderr = writer
            }
            self.process = proc
            try await proc.start()

            requestPwd()

            let exitCode = try await proc.wait()
            flushCurrentLine()
            lines.append(TerminalLine(text: "[Process exited with code \(exitCode)]"))
            scrollToken = UUID()
        } catch {
            lines.append(TerminalLine(text: "[Error: \(error.localizedDescription)]"))
            scrollToken = UUID()
        }
        isActive = false
    }

    func send(_ text: String) {
        inputReader.send(text)
    }

    func sendCommand(_ command: String) {
        inputReader.send(command + "\n")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.requestPwd()
        }
    }

    func sendRaw(_ data: Data) {
        inputReader.sendRaw(data)
    }

    func sendControlC() {
        inputReader.sendRaw(Data([0x03]))
    }

    func sendControlD() {
        inputReader.sendRaw(Data([0x04]))
    }

    func clearScreen() {
        lines.removeAll()
        currentLine = ""
        scrollToken = UUID()
    }

    private func requestPwd() {
        pendingPwdRead = true
        inputReader.send("pwd\n")
    }

    private func processOutput(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }

        let hasClear = raw.contains("\u{1b}[2J") || raw.contains("\u{1b}[H\u{1b}[2J")
            || raw.contains("\u{1b}[3J")

        let cleaned = stripANSI(raw)

        if hasClear {
            lines.removeAll()
            currentLine = ""
        }

        let chars = Array(cleaned)
        var ci = 0
        while ci < chars.count {
            let char = chars[ci]
            if char == "\r" {
                if ci + 1 < chars.count && chars[ci + 1] == "\n" {
                    commitLine()
                    ci += 2
                } else {
                    currentLine = ""
                    ci += 1
                }
            } else if char == "\n" {
                commitLine()
                ci += 1
            } else if char == "\u{7}" {
                ci += 1
            } else if char == "\u{8}" {
                if !currentLine.isEmpty { currentLine.removeLast() }
                ci += 1
            } else {
                currentLine.append(char)
                ci += 1
            }
        }

        if lines.count > 10000 {
            lines.removeFirst(lines.count - 10000)
        }

        scrollToken = UUID()
    }

    private func commitLine() {
        let trimmed = currentLine.trimmingCharacters(in: .whitespaces)

        if pendingPwdRead && trimmed.hasPrefix("/") && !trimmed.contains(" ") {
            workingDirectory = trimmed
            pendingPwdRead = false
            currentLine = ""
            return
        }
        if pendingPwdRead && trimmed == "pwd" {
            currentLine = ""
            return
        }

        lines.append(TerminalLine(text: currentLine))
        currentLine = ""
    }

    private func flushCurrentLine() {
        if !currentLine.isEmpty {
            lines.append(TerminalLine(text: currentLine))
            currentLine = ""
        }
    }

    private func stripANSI(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\u{1b}" {
                let next = text.index(after: i)
                if next < text.endIndex {
                    if text[next] == "[" {
                        var j = text.index(after: next)
                        while j < text.endIndex {
                            let ascii = text[j].asciiValue ?? 0
                            if ascii >= 0x40 && ascii <= 0x7E {
                                i = text.index(after: j)
                                break
                            }
                            j = text.index(after: j)
                        }
                        if j >= text.endIndex { i = j }
                        continue
                    } else if text[next] == "]" {
                        var j = text.index(after: next)
                        while j < text.endIndex {
                            if text[j] == "\u{7}" {
                                i = text.index(after: j)
                                break
                            }
                            if text[j] == "\u{1b}" {
                                let k = text.index(after: j)
                                if k < text.endIndex && text[k] == "\\" {
                                    i = text.index(after: k)
                                    break
                                }
                            }
                            j = text.index(after: j)
                        }
                        if j >= text.endIndex { i = j }
                        continue
                    } else {
                        i = text.index(after: next)
                        continue
                    }
                }
            }
            result.append(text[i])
            i = text.index(after: i)
        }
        return result
    }
}
