import SwiftUI

struct VolumesView: View {
    var manager: CrateManager
    @State private var showCreate = false

    var body: some View {
        Group {
            if manager.volumes.isEmpty {
                ContentUnavailableView {
                    Label("No Volumes", systemImage: "externaldrive")
                } description: {
                    Text("Volumes provide persistent storage that survives container restarts.")
                    Button("Create Volume") {
                        showCreate = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(manager.volumes) { volume in
                        VolumeRow(volume: volume, manager: manager)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Volume")
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateVolumeSheet(manager: manager)
        }
    }
}

struct VolumeRow: View {
    let volume: CrateVolume
    var manager: CrateManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(volume.attachedTo != nil ? .blue : .secondary)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(.headline)
                Text(volume.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            Text(volume.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            if let attached = volume.attachedTo {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text(attached)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            } else {
                Text("Available")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Text(volume.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                manager.deleteVolume(id: volume.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete volume")
            .disabled(volume.attachedTo != nil)
        }
        .padding(.vertical, 4)
    }
}

struct CreateVolumeSheet: View {
    var manager: CrateManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Volume")
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
                Section {
                    TextField("Volume name", text: $name)
                } footer: {
                    Text("Volumes use shared directories — they grow dynamically as data is written.")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    manager.createVolume(name: name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 280)
    }
}
