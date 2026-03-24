import SwiftUI

struct LogsView: View {
    var manager: CrateManager
    @State private var searchText = ""
    @State private var filterLevel: LogEntry.Level?

    private var filteredLogs: [LogEntry] {
        manager.logs.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText) || entry.source.localizedCaseInsensitiveContains(searchText)
            let matchesLevel = filterLevel == nil || entry.level == filterLevel
            return matchesSearch && matchesLevel
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.plain)

                Picker("Level", selection: $filterLevel) {
                    Text("All").tag(nil as LogEntry.Level?)
                    Text("Info").tag(LogEntry.Level.info as LogEntry.Level?)
                    Text("Warning").tag(LogEntry.Level.warning as LogEntry.Level?)
                    Text("Error").tag(LogEntry.Level.error as LogEntry.Level?)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Button("Clear") {
                    manager.logs.removeAll()
                }
                .disabled(manager.logs.isEmpty)
            }
            .padding()

            Divider()

            if filteredLogs.isEmpty {
                Spacer()
                
                ContentUnavailableView {
                    Label("No Logs", systemImage: "doc.text")
                } description: {
                    Text(manager.logs.isEmpty ? "Logs will appear here as you manage containers and images." : "No logs match the current filter.")
                }
                
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(filteredLogs) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.formattedTime)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .leading)

                            Circle()
                                .fill(entry.level.color)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)

                            Text(entry.source)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Text(entry.message)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .id(entry.id)
                    }
                    .listStyle(.plain)
                    .onChange(of: manager.logs.count) {
                        if let last = filteredLogs.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("Logs")
    }
}
