import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case containers = "Containers"
    case images = "Images"
    case logs = "Logs"

    var id: Self { self }

    var icon: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "square.stack.3d.up"
        case .logs: "doc.text.magnifyingglass"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .containers
    @State private var manager = CrateManager()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("Crate")
            .listStyle(.sidebar)

            Spacer()

            if manager.isInitializing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting runtime...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else if manager.managerReady {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Runtime ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("Runtime unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        } detail: {
            Group {
                switch selection {
                case .containers:
                    ContainersView(manager: manager)
                case .images:
                    ImagesView(manager: manager)
                case .logs:
                    LogsView(manager: manager)
                case nil:
                    ContentUnavailableView("Select a section", systemImage: "shippingbox", description: Text("Choose from the sidebar"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
