import SwiftUI

struct ContainerSummary: Identifiable {
    enum Status: String, CaseIterable {
        case running
        case stopped
        case error

        var color: Color {
            switch self {
            case .running: .green
            case .stopped: .gray
            case .error: .red
            }
        }
    }

    let id = UUID()
    let name: String
    let image: String
    let uptime: String
    let status: Status
}

struct ImageSummary: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let created: String
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let message: String
}

struct ContentView: View {
    @State private var searchLogs = ""

    private let containers: [ContainerSummary] = [
        .init(name: "postgres-dev", image: "postgres:17", uptime: "2h 14m", status: .running),
        .init(name: "redis-cache", image: "redis:7", uptime: "45m", status: .running),
        .init(name: "worker-staging", image: "ghcr.io/crate/worker:latest", uptime: "Stopped", status: .stopped),
        .init(name: "ml-inference", image: "python:3.12-slim", uptime: "CrashLoop", status: .error)
    ]

    private let images: [ImageSummary] = [
        .init(name: "docker.io/library/alpine:latest", size: "8.2 MB", created: "Today"),
        .init(name: "postgres:17", size: "357 MB", created: "1 day ago"),
        .init(name: "redis:7", size: "154 MB", created: "3 days ago")
    ]

    private let logs: [LogEntry] = [
        .init(timestamp: "12:40:07", message: "postgres-dev | ready to accept connections"),
        .init(timestamp: "12:40:12", message: "redis-cache | background saving started"),
        .init(timestamp: "12:41:31", message: "ml-inference | failed to bind to port 8080")
    ]

    private var filteredLogs: [LogEntry] {
        guard !searchLogs.isEmpty else { return logs }
        return logs.filter { $0.message.localizedCaseInsensitiveContains(searchLogs) }
    }

    var body: some View {
        NavigationSplitView {
            List {
                Label("Containers", systemImage: "shippingbox")
                Label("Images", systemImage: "square.stack.3d.up")
                Label("Logs", systemImage: "doc.text.magnifyingglass")
                Label("Create", systemImage: "slider.horizontal.3")
            }
            .navigationTitle("Crate")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    containerManagement
                    imageManagement
                    logsPanel
                    creationPanel
                }
                .padding(20)
            }
            .background(.regularMaterial)
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crate")
                .font(.largeTitle.bold())
            Text("Native container dashboard for Apple Containerization")
                .foregroundStyle(.secondary)
        }
    }

    private var containerManagement: some View {
        GroupBox("Container Management") {
            VStack(spacing: 10) {
                ForEach(containers) { container in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(container.name)
                                .font(.headline)
                            Text(container.image)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Label(container.status.rawValue.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(container.status.color)

                        Text(container.uptime)
                            .font(.caption)
                            .frame(width: 90, alignment: .trailing)

                        HStack(spacing: 8) {
                            Button("Start") {}
                            Button("Stop") {}
                            Button("Delete", role: .destructive) {}
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var imageManagement: some View {
        GroupBox("Image Management") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Pull image (e.g. docker.io/library/alpine:latest)", text: .constant(""))
                    Button("Pull") {}
                        .buttonStyle(.borderedProminent)
                }

                ForEach(images) { image in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(image.name)
                            Text("\(image.size) • \(image.created)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Inspect") {}
                        Button("Remove", role: .destructive) {}
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var logsPanel: some View {
        GroupBox("Logs & Monitoring") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Search logs", text: $searchLogs)
                    Button("Export") {}
                        .buttonStyle(.bordered)
                }

                ForEach(filteredLogs) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.timestamp)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var creationPanel: some View {
        GroupBox("Container Creation") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Image") {
                    Text("docker.io/library/alpine:latest")
                }

                HStack {
                    Text("CPU")
                    Slider(value: .constant(2), in: 1...8, step: 1)
                    Text("2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Memory")
                    Slider(value: .constant(2048), in: 256...8192, step: 256)
                    Text("2048 MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Save Preset") {}
                    Button("Create Container") {}
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
