import SwiftUI

struct ContainersView: View {
    var manager: CrateManager
    @State private var showCreate = false

    var body: some View {
        Group {
            if manager.containers.isEmpty {
                ContentUnavailableView {
                    Label("No Containers", systemImage: "shippingbox")
                } description: {
                    Button("Create Container", action: {
                        showCreate = true;
                    })
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(manager.containers) { container in
                        ContainerRow(container: container, manager: manager)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Container")
                .disabled(!manager.managerReady)
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateContainerSheet(manager: manager)
        }
    }
}
