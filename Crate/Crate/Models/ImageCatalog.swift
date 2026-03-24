import Foundation

struct ImageCatalogEntry: Identifiable {
    let id = UUID()
    let reference: String
    let description: String
}

let defaultImages: [ImageCatalogEntry] = [
    .init(reference: "docker.io/library/alpine:latest", description: "Minimal Alpine Linux (arm64) - ~8 MB"),
    .init(reference: "docker.io/library/ubuntu:24.04", description: "Ubuntu 24.04 LTS - ~78 MB"),
    .init(reference: "docker.io/library/debian:bookworm-slim", description: "Debian 12 Slim - ~75 MB"),
    .init(reference: "docker.io/library/busybox:latest", description: "BusyBox - ~4 MB"),
    .init(reference: "docker.io/library/nginx:alpine", description: "Nginx on Alpine - ~43 MB"),
    .init(reference: "docker.io/library/python:3.12-alpine", description: "Python 3.12 on Alpine - ~55 MB"),
    .init(reference: "docker.io/library/node:22-alpine", description: "Node.js 22 on Alpine - ~130 MB"),
    .init(reference: "docker.io/library/redis:7-alpine", description: "Redis 7 on Alpine - ~35 MB"),
    .init(reference: "docker.io/library/postgres:17-alpine", description: "PostgreSQL 17 on Alpine - ~240 MB"),
]
