//
//  ContentView.swift
//  Crate
//
//  Created by Jude Wilson (Bethel) on 8/2/25.
//

// 🌋 PullAlpineTestView.swift

// CratePullAlpine.swift

// CratePullAlpine.swift

import SwiftUI
import Containerization
import ContainerizationOCI
import ContainerizationExtras
import ContainerizationArchive
import ContainerizationOS

@MainActor
class AlpinePuller: ObservableObject {
    @Published var logs: String = ""
    @Published var isBusy = false

    func appendLog(_ line: String) {
        logs += "\n" + line
    }

    func pullAndRun() {
        guard !isBusy else { return }
        isBusy = true
        logs = "🧊 Pulling & Running Alpine (docker.io/library/alpine:latest)\n------------------------"

        Task {
            do {
                appendLog("🛠 Creating ImageStore…")
                let tempDir = FileManager.default.uniqueTemporaryDirectory(create: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }

                let contentStore = try LocalContentStore(path: tempDir)
                let imageStore = try ImageStore(path: tempDir, contentStore: contentStore)

                //let auth = BasicAuthentication(username: "alechash", password: "")
                //let reference = "ghcr.io/linuxcontainers/alpine:latest"
                
                let reference = "docker.io/library/alpine:latest"
                
                let image = try await imageStore.pull(reference: reference, auth: nil)

                appendLog("✅ Pulled: \(image.descriptor.digest)")

                appendLog("🧠 Setting up kernel and manager…")
                //let kernelPath = "Crate/vmlinuz-6.12.28-153"
                
                
                
                var kernel: Kernel;
                
                if let kernelURL = Bundle.main.url(forResource: "vmlinuz-6.12.28-153", withExtension: nil) {
#if arch(arm64)
                    kernel = Kernel(path: kernelURL, platform: .linuxArm)
#else
                    kernel = Kernel(path: kernelURL, platform: .linuxAmd)
#endif
                } else {
                    fatalError("Kernel file not found in bundle.")
                }

                let manager = try await ContainerManager(
                    kernel: kernel,
                    initfsReference: image.reference
                )
                
                appendLog("🚧 Creating container…")
                let container = try await manager.create(
                    "crate-alpine-\(UUID().uuidString.prefix(6))",
                    reference: image.reference,
                    rootfsSizeInBytes: 1024 * 1024 * 1024
                ) { config in
                    appendLog("Config in")
                    config.cpus = 2
                    config.memoryInBytes = 1024 * 1024 * 1024
                    config.rosetta = false
                }
                
                appendLog("Config out")
                                
                try await container.create()
                
                appendLog("Container in")
                
                appendLog("🔋 Starting container \(container.id)…")
                try await container.start()

                appendLog("🚀 Container running. Waiting to exit…")
                try await container.wait()
                appendLog("🛑 Container exited.")

            } catch {
                appendLog("❌ Error: \(error)")
                print(error)
            }

            isBusy = false
        }
    }
}

struct CratePullView: View {
    @StateObject var puller = AlpinePuller()

    var body: some View {
        VStack(alignment: .leading) {
            Text("🪨 Crate: Pull & Run Alpine")
                .font(.title2).bold()

            ScrollView {
                Text(puller.logs)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .border(Color.secondary)

            Button(action: {
                puller.pullAndRun()
            }) {
                Text(puller.isBusy ? "Running…" : "Pull & Run Alpine")
            }
            .disabled(puller.isBusy)
            .padding(.top, 8)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
