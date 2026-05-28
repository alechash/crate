import SwiftUI
import Charts

/// Live resource readout for a running container: current value + rolling
/// sparkline per metric. Reads from a `ContainerStatsMonitor`.
struct ContainerStatsView: View {
    var monitor: ContainerStatsMonitor

    var body: some View {
        if let error = monitor.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else if monitor.history.isEmpty {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Collecting metrics…").foregroundStyle(.secondary)
            }
        } else {
            let h = monitor.history
            let latest = monitor.latest

            StatRow(
                title: "CPU",
                value: latest.map { String(format: "%.0f%%", $0.cpuPercent) } ?? "—",
                values: h.map(\.cpuPercent),
                tint: .blue,
                yDomain: 0...100
            )
            StatRow(
                title: "Memory",
                value: latest.map { "\(Self.bytes($0.memUsedBytes)) / \(Self.bytes($0.memTotalBytes)) (\(Int($0.memPercent))%)" } ?? "—",
                values: h.map(\.memPercent),
                tint: .green,
                yDomain: 0...100
            )
            StatRow(
                title: "Net ↓",
                value: latest.map { Self.rate($0.netRxBytesPerSec) } ?? "—",
                values: h.map(\.netRxBytesPerSec),
                tint: .teal
            )
            StatRow(
                title: "Net ↑",
                value: latest.map { Self.rate($0.netTxBytesPerSec) } ?? "—",
                values: h.map(\.netTxBytesPerSec),
                tint: .purple
            )
            StatRow(
                title: "Disk R",
                value: latest.map { Self.rate($0.diskReadBytesPerSec) } ?? "—",
                values: h.map(\.diskReadBytesPerSec),
                tint: .orange
            )
            StatRow(
                title: "Disk W",
                value: latest.map { Self.rate($0.diskWriteBytesPerSec) } ?? "—",
                values: h.map(\.diskWriteBytesPerSec),
                tint: .pink
            )
        }
    }

    static func rate(_ bytesPerSec: Double) -> String { bytes(bytesPerSec) + "/s" }

    static func bytes(_ value: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(0, value)
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return String(format: i == 0 ? "%.0f %@" : "%.1f %@", v, units[i])
    }

    static func bytes(_ value: UInt64) -> String { bytes(Double(value)) }
}

private struct StatRow: View {
    let title: String
    let value: String
    let values: [Double]
    let tint: Color
    var yDomain: ClosedRange<Double>?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Sparkline(values: values, tint: tint, yDomain: yDomain)
                .frame(height: 26)

            Text(value)
                .font(.system(.callout, design: .monospaced))
                .frame(minWidth: 120, alignment: .trailing)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let tint: Color
    var yDomain: ClosedRange<Double>?

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("t", index), y: .value("v", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
            AreaMark(x: .value("t", index), y: .value("v", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint.opacity(0.12))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain ?? 0...max(1, (values.max() ?? 1)))
    }
}
