import Foundation

/// Raw cumulative counters parsed from a single `/proc` sampling frame.
/// Rates and CPU% are derived by diffing two snapshots over their time delta.
struct ProcStatsSnapshot {
    let timestamp: Date
    let cpuTotal: UInt64
    let cpuIdle: UInt64
    let memTotalBytes: UInt64
    let memAvailableBytes: UInt64
    let netRxBytes: UInt64
    let netTxBytes: UInt64
    let diskReadBytes: UInt64
    let diskWriteBytes: UInt64
}

/// Pure parsing/derivation of container resource usage from `/proc` text.
/// No I/O — `ContainerStatsMonitor` owns the exec channel and feeds frames here.
enum ProcStatsParser {
    static let beginMarker = "__CRATE_STATS_BEGIN__"
    static let endMarker = "__CRATE_STATS_END__"
    private static let statMarker = "__STAT__"
    private static let memMarker = "__MEMINFO__"
    private static let netMarker = "__NETDEV__"
    private static let diskMarker = "__DISK__"

    /// Shell command run inside the guest that streams labelled `/proc` frames.
    static func samplerCommand(intervalSeconds: Int) -> String {
        "while true; do "
            + "echo \(beginMarker); "
            + "echo \(statMarker); cat /proc/stat; "
            + "echo \(memMarker); cat /proc/meminfo; "
            + "echo \(netMarker); cat /proc/net/dev; "
            + "echo \(diskMarker); cat /proc/diskstats; "
            + "echo \(endMarker); "
            + "sleep \(intervalSeconds); "
            + "done"
    }

    /// Parse the text between a BEGIN and END marker into a counter snapshot.
    /// Returns nil if the required CPU/memory sections can't be read.
    static func parseFrame(_ frame: String, at timestamp: Date) -> ProcStatsSnapshot? {
        var section = ""
        var statLines: [String] = []
        var memLines: [String] = []
        var netLines: [String] = []
        var diskLines: [String] = []

        for raw in frame.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            switch line.trimmingCharacters(in: .whitespaces) {
            case statMarker: section = "stat"; continue
            case memMarker: section = "mem"; continue
            case netMarker: section = "net"; continue
            case diskMarker: section = "disk"; continue
            case beginMarker, endMarker, "": continue
            default: break
            }
            switch section {
            case "stat": statLines.append(line)
            case "mem": memLines.append(line)
            case "net": netLines.append(line)
            case "disk": diskLines.append(line)
            default: break
            }
        }

        guard let cpu = parseCPU(statLines), let mem = parseMem(memLines) else { return nil }
        let net = parseNet(netLines)
        let disk = parseDisk(diskLines)

        return ProcStatsSnapshot(
            timestamp: timestamp,
            cpuTotal: cpu.total, cpuIdle: cpu.idle,
            memTotalBytes: mem.total, memAvailableBytes: mem.available,
            netRxBytes: net.rx, netTxBytes: net.tx,
            diskReadBytes: disk.read, diskWriteBytes: disk.write
        )
    }

    /// Derive a usage sample from two consecutive snapshots.
    static func sample(from prev: ProcStatsSnapshot, to cur: ProcStatsSnapshot) -> ResourceSample {
        let dt = cur.timestamp.timeIntervalSince(prev.timestamp)

        let cpuPercent: Double = {
            let totalDelta = cur.cpuTotal >= prev.cpuTotal ? cur.cpuTotal - prev.cpuTotal : 0
            let idleDelta = cur.cpuIdle >= prev.cpuIdle ? cur.cpuIdle - prev.cpuIdle : 0
            guard totalDelta > 0 else { return 0 }
            let busyDelta = totalDelta >= idleDelta ? totalDelta - idleDelta : 0
            return min(100, Double(busyDelta) / Double(totalDelta) * 100)
        }()

        func rate(_ a: UInt64, _ b: UInt64) -> Double {
            guard dt > 0, b >= a else { return 0 }
            return Double(b - a) / dt
        }

        let memUsed = cur.memTotalBytes >= cur.memAvailableBytes
            ? cur.memTotalBytes - cur.memAvailableBytes : 0

        return ResourceSample(
            timestamp: cur.timestamp,
            cpuPercent: cpuPercent,
            memUsedBytes: memUsed,
            memTotalBytes: cur.memTotalBytes,
            netRxBytesPerSec: rate(prev.netRxBytes, cur.netRxBytes),
            netTxBytesPerSec: rate(prev.netTxBytes, cur.netTxBytes),
            diskReadBytesPerSec: rate(prev.diskReadBytes, cur.diskReadBytes),
            diskWriteBytesPerSec: rate(prev.diskWriteBytes, cur.diskWriteBytes)
        )
    }

    // MARK: - Section parsers

    private static func parseCPU(_ lines: [String]) -> (total: UInt64, idle: UInt64)? {
        for line in lines where line.hasPrefix("cpu ") || line.hasPrefix("cpu\t") {
            let fields = line.split(whereSeparator: isSpace).dropFirst().compactMap { UInt64($0) }
            // user nice system idle iowait irq softirq steal
            guard fields.count >= 5 else { return nil }
            let idle = fields[3] + fields[4]
            let total = fields.prefix(8).reduce(0, +)
            return (total, idle)
        }
        return nil
    }

    private static func parseMem(_ lines: [String]) -> (total: UInt64, available: UInt64)? {
        var total: UInt64?
        var available: UInt64?
        for line in lines {
            if line.hasPrefix("MemTotal:") { total = firstNumber(line).map { $0 * 1024 } }
            else if line.hasPrefix("MemAvailable:") { available = firstNumber(line).map { $0 * 1024 } }
        }
        guard let t = total else { return nil }
        return (t, available ?? 0)
    }

    private static func parseNet(_ lines: [String]) -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let iface = line[..<colon].trimmingCharacters(in: .whitespaces)
            if iface == "lo" || iface.isEmpty { continue }
            let nums = line[line.index(after: colon)...].split(whereSeparator: isSpace).compactMap { UInt64($0) }
            guard nums.count >= 9 else { continue }
            rx += nums[0]   // receive bytes
            tx += nums[8]   // transmit bytes
        }
        return (rx, tx)
    }

    private static func parseDisk(_ lines: [String]) -> (read: UInt64, write: UInt64) {
        var read: UInt64 = 0
        var write: UInt64 = 0
        for line in lines {
            let fields = line.split(whereSeparator: isSpace).map(String.init)
            guard fields.count >= 10 else { continue }
            let name = fields[2]
            guard name.hasPrefix("vd") || name.hasPrefix("sd") || name.hasPrefix("nvme") else { continue }
            // Skip partitions to avoid double-counting whole disks.
            if (name.hasPrefix("vd") || name.hasPrefix("sd")), let last = name.last, last.isNumber { continue }
            if name.hasPrefix("nvme"), name.contains("p") { continue }
            read += (UInt64(fields[5]) ?? 0) * 512   // sectors read * 512B
            write += (UInt64(fields[9]) ?? 0) * 512  // sectors written * 512B
        }
        return (read, write)
    }

    private static func firstNumber(_ line: String) -> UInt64? {
        for token in line.split(whereSeparator: isSpace) {
            if let n = UInt64(token) { return n }
        }
        return nil
    }

    private static func isSpace(_ c: Character) -> Bool { c == " " || c == "\t" }
}
