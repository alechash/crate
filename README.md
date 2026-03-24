# Crate

A native macOS GUI for managing Linux containers using Apple's [Containerization](https://github.com/apple/containerization) framework. No Docker, no Podman — just Apple Silicon and Virtualization.framework.

![Swift](https://img.shields.io/badge/Swift-6-orange)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Container lifecycle management** — Create, start, stop, and delete Linux containers
- **Built-in terminal** — Shell into running containers directly from the app, with pop-out window support
- **Image management** — Pull, inspect, and remove OCI images from any registry
- **Network configuration** — vmnet-based networking with custom DNS and hostname settings
- **Live logs** — Filterable log stream for all container and runtime events
- **Quick pull catalog** — One-click pull for common base images (Alpine, Ubuntu, Debian, Fedora, Nginx)

## Requirements

- **macOS 26** (Tahoe) or later
- **Apple Silicon** (M1 or newer)
- **Xcode 26+** with Swift 6
- The `container` CLI runtime must be installed and started:
  ```
  container system start
  ```

## Getting Started

### Build from source

```bash
git clone https://github.com/alechash/crate.git
cd crate
open Crate/Crate.xcodeproj
```

Build and run from Xcode (Cmd+R). The app requires the sandbox to be disabled and uses the `com.apple.security.virtualization` entitlement.

### First launch

1. Make sure the container runtime is running (`container system start`)
2. Launch Crate — the sidebar will show "Runtime ready" with a green dot once initialized
3. Go to **Images** and pull a base image, or use the quick pull cards
4. Go to **Containers**, click **+** to create and start a container
5. Click the terminal icon on a running container to open a shell

## Architecture

```
Crate/
├── CrateApp.swift                 # App entry point and window groups
├── ContentView.swift              # Root navigation (sidebar + detail)
├── Models/
│   ├── ManagedContainer.swift     # Container data model
│   ├── ManagedImage.swift         # Image data model
│   ├── LogEntry.swift             # Log entry with level filtering
│   ├── ImageCatalog.swift         # Quick-pull image catalog
│   └── CrateError.swift           # Error types
├── Manager/
│   └── CrateManager.swift         # Core runtime manager (images, containers, networking)
├── Terminal/
│   ├── ContainerTerminalSession.swift  # Terminal session with ANSI handling
│   ├── TerminalIO.swift           # Writer/ReaderStream bridge for container I/O
│   └── TerminalView.swift         # Terminal UI with history, clear, pop-out
└── Views/
    ├── ContainersView.swift       # Container list
    ├── ContainerRow.swift         # Container row with action buttons
    ├── CreateContainerSheet.swift  # Container creation form (resources, network, DNS)
    ├── ImagesView.swift           # Image list with pull and quick-pull
    └── LogsView.swift             # Searchable, filterable log viewer
```

## How It Works

Crate uses Apple's `Containerization` Swift framework directly — it does **not** shell out to the `container` CLI. It shares the same image store (`~/Library/Application Support/com.apple.container/`) and kernel, so images pulled via the CLI are visible in Crate and vice versa.

Each container runs in its own lightweight Linux VM via Virtualization.framework. Networking uses `VmnetNetwork` for NAT-based internet access with configurable DNS.

## Configuration

When creating a container, you can configure:

| Setting | Default |
|---|---|
| Base image | `docker.io/library/alpine:latest` |
| CPUs | 2 |
| Memory | 1024 MB |
| Command | `sleep infinity` |
| Networking | Enabled |
| DNS | Gateway (auto) |
| Hostname | Auto-generated |

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes and verify the build succeeds in Xcode
4. Submit a pull request

### Areas where help is appreciated

- Volume/mount management UI
- Container resource monitoring (CPU/memory graphs)
- Menu bar quick-access widget
- Container presets and templates
- Automated tests

## License

MIT License — Copyright (c) Alec Wilson

See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Apple Containerization framework](https://github.com/apple/containerization)
- [WWDC 2025: Meet Containerization](https://developer.apple.com/videos/play/wwdc2025/346/)
