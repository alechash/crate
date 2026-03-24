import SwiftUI
import Containerization

@MainActor
@Observable
final class CrateManager {
    var containers: [ManagedContainer] = []
    var images: [ManagedImage] = []
    var logs: [LogEntry] = []

    var isLoadingImages = false
    var isPulling = false
    var isInitializing = false
    var pullProgress: String = ""
    var errorMessage: String?
    var managerReady = false

    // Use the same image store as the `container` CLI (com.apple.container, not com.apple.containerization)
    private let imageStore: ImageStore = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.apple.container")
        return (try? ImageStore(path: root)) ?? ImageStore.default
    }()

    private var containerManager: Containerization.ContainerManager?

    private var kernelURL: URL? {
        let cliKernel = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.apple.container/kernels/vmlinux-6.12.28-153")
        if let url = cliKernel, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return Bundle.main.url(forResource: "vmlinuz-6.12.28-153", withExtension: nil)
    }

    private static let initfsRef = "ghcr.io/apple/containerization/vminit:0.5.0"

    private var initfsPath: URL {
        imageStore.path.appendingPathComponent("initfs.ext4")
    }

    init() {
        Task {
            await refreshImages()
            await initializeManager()
        }
    }

    func appendLog(_ message: String, source: String = "crate", level: LogEntry.Level = .info) {
        logs.append(LogEntry(timestamp: Date(), source: source, message: message, level: level))
    }

    // MARK: - Manager initialization

    private func initializeManager() async {
        isInitializing = true
        defer { isInitializing = false }

        guard let kernelPath = kernelURL else {
            appendLog("Kernel binary not found in app bundle", level: .error)
            return
        }

        appendLog("Initializing container runtime...")
        let kernel = Kernel(path: kernelPath, platform: .linuxArm)

        var network: Containerization.ContainerManager.VmnetNetwork?
        do {
            network = try .init()
            appendLog("Network ready (subnet: \(network!.subnet))")
        } catch {
            appendLog("Network setup failed: \(error.localizedDescription) — containers will have no network", level: .warning)
        }

        if FileManager.default.fileExists(atPath: initfsPath.path) {
            appendLog("Found existing initfs at \(initfsPath.lastPathComponent)")
            let initfs: Containerization.Mount = .block(
                format: "ext4",
                source: initfsPath.path(percentEncoded: false),
                destination: "/",
                options: ["ro"]
            )
            do {
                let mgr = try Containerization.ContainerManager(
                    kernel: kernel,
                    initfs: initfs,
                    network: network
                )
                containerManager = mgr
                managerReady = true
                appendLog("Container runtime ready (using existing initfs)")
                return
            } catch {
                appendLog("Failed to init with existing initfs: \(error.localizedDescription)", level: .warning)
            }
        }

        do {
            let mgr = try await Containerization.ContainerManager(
                kernel: kernel,
                initfsReference: Self.initfsRef,
                network: network
            )
            containerManager = mgr
            managerReady = true
            appendLog("Container runtime ready")
        } catch {
            appendLog("Runtime init failed: \(error.localizedDescription)", level: .error)
            appendLog("Run 'container system start' in Terminal to set up the init image, then relaunch Crate.", level: .warning)
        }
    }

    private func ensureManager() throws -> Containerization.ContainerManager {
        guard let mgr = containerManager else {
            throw CrateError.runtimeNotReady
        }
        return mgr
    }

    // MARK: - Image operations

    func refreshImages() async {
        isLoadingImages = true
        defer { isLoadingImages = false }

        do {
            let storeImages = try await imageStore.list()
            images = storeImages.map { img in
                ManagedImage(
                    id: img.digest,
                    reference: img.reference,
                    digest: img.digest,
                    mediaType: img.mediaType
                )
            }
            appendLog("Loaded \(images.count) image(s) from store")
        } catch {
            appendLog("Failed to list images: \(error.localizedDescription)", level: .error)
        }
    }

    func pullImage(reference: String) async {
        guard !reference.isEmpty else { return }
        isPulling = true
        pullProgress = "Pulling \(reference)..."
        appendLog("Pulling image: \(reference)")

        do {
            _ = try await imageStore.pull(reference: reference)
            pullProgress = ""
            appendLog("Successfully pulled \(reference)")
            await refreshImages()
        } catch {
            appendLog("Pull failed: \(error.localizedDescription)", level: .error)
            errorMessage = "Failed to pull \(reference): \(error.localizedDescription)"
        }
        isPulling = false
    }

    func deleteImage(reference: String) async {
        appendLog("Deleting image: \(reference)")
        do {
            try await imageStore.delete(reference: reference)
            appendLog("Deleted \(reference)")
            await refreshImages()
        } catch {
            appendLog("Failed to delete \(reference): \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Container operations

    func createAndStartContainer(
        name: String,
        imageRef: String,
        cpus: Int,
        memoryMB: UInt64,
        command: [String],
        enableNetworking: Bool = true,
        dnsServers: [String] = [],
        hostname: String = ""
    ) async {
        let id = name.isEmpty ? String(UUID().uuidString.prefix(8).lowercased()) : name
        appendLog("Creating container '\(id)' from \(imageRef)")

        do {
            let mgr = try ensureManager()

            appendLog("Pulling/resolving image \(imageRef)...")
            let container = try await mgr.create(
                id,
                reference: imageRef,
                rootfsSizeInBytes: 2048 * 1024 * 1024
            ) { config in
                config.cpus = cpus
                config.memoryInBytes = UInt64(memoryMB) * 1024 * 1024
                if !command.isEmpty {
                    config.process.arguments = command
                }
                if !hostname.isEmpty {
                    config.hostname = hostname
                }
                if !enableNetworking {
                    config.interfaces = []
                    config.dns = nil
                } else if !dnsServers.isEmpty {
                    config.dns = .init(nameservers: dnsServers)
                }
            }

            containers.append(ManagedContainer(
                id: id,
                name: id,
                imageRef: imageRef,
                status: .stopped,
                uptime: "Starting...",
                cpus: cpus,
                memoryMB: memoryMB,
                container: container
            ))

            appendLog("Booting VM for '\(id)'...")
            try await container.create()

            appendLog("Starting process in '\(id)'...")
            try await container.start()

            if let idx = containers.firstIndex(where: { $0.id == id }) {
                containers[idx].status = .running
                containers[idx].uptime = "Just started"
            }
            appendLog("Container '\(id)' is running")
        } catch {
            if let idx = containers.firstIndex(where: { $0.id == id }) {
                containers[idx].status = .error
                containers[idx].uptime = "Failed"
            } else {
                containers.append(ManagedContainer(
                    id: id, name: id, imageRef: imageRef,
                    status: .error, uptime: "Failed",
                    cpus: cpus, memoryMB: memoryMB, container: nil
                ))
            }
            appendLog("Failed to start '\(id)': \(error.localizedDescription)", level: .error)
        }
    }

    func stopContainer(id: String) async {
        guard let idx = containers.firstIndex(where: { $0.id == id }) else { return }
        appendLog("Stopping container '\(id)'")

        do {
            try await containers[idx].container?.stop()
            containers[idx].status = .stopped
            containers[idx].uptime = "Stopped"
            appendLog("Container '\(id)' stopped")
        } catch {
            containers[idx].status = .error
            appendLog("Error stopping '\(id)': \(error.localizedDescription)", level: .error)
        }
    }

    func deleteContainer(id: String) async {
        guard let idx = containers.firstIndex(where: { $0.id == id }) else { return }

        if containers[idx].status == .running {
            await stopContainer(id: id)
        }

        appendLog("Deleting container '\(id)'")
        if let mgr = containerManager {
            do {
                try mgr.delete(id)
            } catch {
                appendLog("Cleanup warning for '\(id)': \(error.localizedDescription)", level: .warning)
            }
        }
        containers.removeAll { $0.id == id }
        appendLog("Container '\(id)' removed")
    }
}
