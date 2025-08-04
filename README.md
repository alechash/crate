# Crate (Concept)

**Crate** is a macOS-native GUI client for Apple’s new container ecosystem, built on top of the [`container`](https://developer.apple.com/documentation/containerization) CLI and the underlying `Containerization` Swift framework. This project aims to provide a polished user interface for managing containers, images, logs, and runtime configuration—offering developers a visual alternative to CLI-based workflows.

---

## Overview

Crate is designed as a lightweight and intuitive application for interacting with Apple containers. It targets developers and power users who want a native tool to manage containers on macOS without relying on Docker, Podman, or third-party runtimes.

---

## Objectives

- Provide a user interface for container lifecycle management using Apple’s native tooling.
- Integrate with the `Containerization` framework directly for maximum performance and future compatibility.
- Visualize containers, logs, images, and runtime details in real-time.
- Offer practical developer utilities (image pulling, runtime config builders, quick start options).

---

## Key Components

### 1. Container Management
- List all running/stopped containers
- View container details (ID, runtime config, filesystem, etc.)
- Start, stop, and delete containers

### 2. Image Management
- View all available images
- Pull images from OCI registries
- Inspect and remove images

### 3. Logs and Monitoring
- Stream logs from active containers
- Search, filter, and export logs
- Status indicators (running, exited, error, etc.)

### 4. Container Creation UI
- Build container run commands via form-based UI
- Configure mounts, environment variables, CPU/memory limits
- Save and reuse common configurations

### 5. Optional Enhancements (Planned)
- Menu bar integration for quick access
- Volume & network management (when/if supported)
- CLI tool companion for scripted use cases
- Container presets and Quick Actions (e.g. right-click a config file to run)

---

## Technologies

| Layer              | Tech                        |
|--------------------|-----------------------------|
| UI Framework       | SwiftUI                     |
| Container API      | Containerization Framework  |
| Reactive Bindings  | Combine                     |
| Runtime Hooks      | gRPC via vsock (`vminitd`)  |
| Distribution       | Swift Package Manager, DMG  |

---

## System Requirements

- **macOS 15 (Sequoia)** or later  
- **Apple Silicon** (M1 chip or newer)  
- **Xcode 16+**  
- **Swift 6**

---

## Development Status

> Crate is currently in the early planning and prototyping phase.

**Immediate goals:**
- Define and test key API integrations using `Containerization`
- Build a minimal container list UI
- Validate real-time log streaming via `vminitd`
- Design modular architecture for future extensibility

---

## Roadmap (v0.1 - v1.0)

| Version | Milestone                                                                 |
|---------|---------------------------------------------------------------------------|
| 0.1     | Container list UI + lifecycle actions (start/stop/delete)                |
| 0.2     | Logs streaming + filtering                                                |
| 0.3     | Image list and image pull support                                         |
| 0.4     | Visual container creation UI                                              |
| 0.5     | Menu bar integration + presets                                            |
| 1.0     | Stable release with documentation, distribution (DMG/homebrew), and tests |

---

## Contributing

This project is open to contributors interested in:
- SwiftUI/macOS development
- Container runtime technology
- Native macOS developer tools

To contribute:
1. Clone the repository
2. Build using Xcode 16+
3. Follow the architecture and feature roadmap

> Contributor guide coming soon.

---

## License

**MIT License** – Copyright © Alec Wilson

---

## References

- [Apple’s WWDC 2025: Meet Containerization](https://developer.apple.com/videos/play/wwdc2025/346/)
- [Containerization GitHub Repo (Unofficial Mirror)](https://github.com/apple/containerization)
- [CLI Documentation: `container`](https://developer.apple.com/documentation/containerization)
- [vminitd.proto – gRPC API spec](https://github.com/apple/containerization/blob/main/container/init/vminitd.proto)
