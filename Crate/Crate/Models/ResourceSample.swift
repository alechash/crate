import Foundation

/// A single point-in-time reading of a container's resource usage.
/// Rates are bytes/second computed from consecutive `/proc` snapshots.
struct ResourceSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuPercent: Double          // 0...100, across all allocated vCPUs
    let memUsedBytes: UInt64
    let memTotalBytes: UInt64
    let netRxBytesPerSec: Double
    let netTxBytesPerSec: Double
    let diskReadBytesPerSec: Double
    let diskWriteBytesPerSec: Double

    var memPercent: Double {
        memTotalBytes == 0 ? 0 : Double(memUsedBytes) / Double(memTotalBytes) * 100
    }
}
