import Foundation
import Containerization

/// Streams live resource usage for one running container by execing a sampler
/// loop in the guest and parsing its `/proc` frames. Owned by the detail view:
/// `start` when the view appears, `stop` when it goes away.
@MainActor
@Observable
final class ContainerStatsMonitor {
    private(set) var history: [ResourceSample] = []
    private(set) var isMonitoring = false
    private(set) var errorMessage: String?

    var latest: ResourceSample? { history.last }

    private let historyCapacity = 60      // ~2 min at the 2s interval
    private let intervalSeconds = 2

    private var process: LinuxProcess?
    private var runTask: Task<Void, Never>?
    private var buffer = ""
    private var previousSnapshot: ProcStatsSnapshot?

    func start(container: LinuxContainer) {
        guard !isMonitoring else { return }
        isMonitoring = true
        errorMessage = nil
        history = []
        buffer = ""
        previousSnapshot = nil

        let command = ProcStatsParser.samplerCommand(intervalSeconds: intervalSeconds)
        let writer = TerminalOutputWriter { [weak self] data in
            Task { @MainActor in self?.ingest(data) }
        }

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let proc = try await container.exec("crate-stats-\(UUID().uuidString.prefix(6))") { config in
                    config.arguments = ["/bin/sh", "-c", command]
                    config.environmentVariables = [
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                    ]
                    config.stdout = writer
                    config.stderr = writer
                }
                self.process = proc
                try await proc.start()
                _ = try await proc.wait()
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Stats unavailable: \(error.localizedDescription)"
                }
            }
            self.isMonitoring = false
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isMonitoring = false
        guard let proc = process else { return }
        process = nil
        Task {
            try? await proc.kill(9)   // SIGKILL — the loop ignores stdin without a TTY
            try? await proc.delete()
        }
    }

    private func ingest(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        while let end = buffer.range(of: ProcStatsParser.endMarker) {
            let frame = String(buffer[buffer.startIndex..<end.lowerBound])
            buffer.removeSubrange(buffer.startIndex..<end.upperBound)
            processFrame(frame)
        }

        // Guard against unbounded growth if an END marker never arrives.
        if buffer.count > 100_000 { buffer = String(buffer.suffix(50_000)) }
    }

    private func processFrame(_ frame: String) {
        guard let snapshot = ProcStatsParser.parseFrame(frame, at: Date()) else { return }
        defer { previousSnapshot = snapshot }
        guard let prev = previousSnapshot else { return }   // first frame seeds the delta

        history.append(ProcStatsParser.sample(from: prev, to: snapshot))
        if history.count > historyCapacity {
            history.removeFirst(history.count - historyCapacity)
        }
    }
}
