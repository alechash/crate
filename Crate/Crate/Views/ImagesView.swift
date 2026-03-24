import SwiftUI

struct ImagesView: View {
    var manager: CrateManager
    @State private var pullReference = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Image reference (e.g. docker.io/library/alpine:latest)", text: $pullReference)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { pullImage() }

                Button(action: pullImage) {
                    if manager.isPulling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Pull")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pullReference.isEmpty || manager.isPulling)

                Button {
                    Task { await manager.refreshImages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding()

            if !manager.pullProgress.isEmpty {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text(manager.pullProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            if manager.images.isEmpty && !manager.isLoadingImages {
                Spacer()
                
                VStack(spacing: 20) {
                    ContentUnavailableView {
                        Label("No Images", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Pull an image from a registry to get started, or choose one below.")
                    }

                    quickPullGrid
                }
                
                Spacer()
            } else {
                List {
                    ForEach(manager.images) { image in
                        ImageRow(image: image, manager: manager)
                    }

                    Section("Quick Pull") {
                        quickPullList
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .overlay {
                    if manager.isLoadingImages {
                        ProgressView("Loading images...")
                    }
                }
            }
        }
        .navigationTitle("Images")
    }

    private var quickPullGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
            ForEach(defaultImages) { entry in
                quickPullCard(entry)
            }
        }
        .padding()
    }

    private func quickPullCard(_ entry: ImageCatalogEntry) -> some View {
        let alreadyPulled = manager.images.contains { $0.reference == entry.reference }
        return Button {
            Task { await manager.pullImage(reference: entry.reference) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.reference.split(separator: "/").last.map(String.init) ?? entry.reference)
                    .font(.headline)
                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(manager.isPulling || alreadyPulled)
        .opacity(alreadyPulled ? 0.5 : 1)
    }

    private var quickPullList: some View {
        ForEach(defaultImages) { entry in
            let alreadyPulled = manager.images.contains { $0.reference == entry.reference }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.reference)
                    Text(entry.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if alreadyPulled {
                    Text("Pulled")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Pull") {
                        Task { await manager.pullImage(reference: entry.reference) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.isPulling)
                }
            }
        }
    }

    private func pullImage() {
        let ref = pullReference.trimmingCharacters(in: .whitespaces)
        pullReference = ""
        Task { await manager.pullImage(reference: ref) }
    }
}

struct ImageRow: View {
    let image: ManagedImage
    var manager: CrateManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(image.reference)
                    .font(.headline)
                Text(image.shortDigest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            Text(image.mediaType.split(separator: ".").last.map(String.init) ?? image.mediaType)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            Button(role: .destructive) {
                Task { await manager.deleteImage(reference: image.reference) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove image")
        }
        .padding(.vertical, 4)
    }
}
