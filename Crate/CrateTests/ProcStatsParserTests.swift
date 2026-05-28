import Testing
import Foundation
@testable import Crate

struct ProcStatsParserTests {
    private func frame(stat: String, mem: String, net: String, disk: String) -> String {
        """
        \(ProcStatsParser.beginMarker)
        __STAT__
        \(stat)
        __MEMINFO__
        \(mem)
        __NETDEV__
        \(net)
        __DISK__
        \(disk)
        \(ProcStatsParser.endMarker)
        """
    }

    @Test func computesUsageFromTwoConsecutiveFrames() throws {
        let netHdr = """
        Inter-|   Receive                                                |  Transmit
         face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
        """
        let f1 = frame(
            stat: "cpu  100 0 50 1000 0 0 0 0 0 0",
            mem: "MemTotal:       1024000 kB\nMemFree: 100000 kB\nMemAvailable:    512000 kB",
            net: "\(netHdr)\n    lo:  500 5 0 0 0 0 0 0 500 5 0 0 0 0 0 0\n  eth0: 1000 10 0 0 0 0 0 0 2000 20 0 0 0 0 0 0",
            disk: " 254       0 vda 5 0 100 10 8 0 200 20 0 30 40\n 254       1 vda1 1 0 10 1 1 0 20 2 0 3 4"
        )
        let f2 = frame(
            stat: "cpu  200 0 100 1800 0 0 0 0 0 0",
            mem: "MemTotal:       1024000 kB\nMemFree: 50000 kB\nMemAvailable:    256000 kB",
            net: "\(netHdr)\n    lo:  900 9 0 0 0 0 0 0 900 9 0 0 0 0 0 0\n  eth0: 3000 30 0 0 0 0 0 0 5000 50 0 0 0 0 0 0",
            disk: " 254       0 vda 9 0 300 10 18 0 400 20 0 30 40\n 254       1 vda1 1 0 10 1 1 0 20 2 0 3 4"
        )

        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1002)   // +2s

        let s0 = try #require(ProcStatsParser.parseFrame(f1, at: t0))
        let s1 = try #require(ProcStatsParser.parseFrame(f2, at: t1))
        let sample = ProcStatsParser.sample(from: s0, to: s1)

        // CPU: ΔTotal=950, Δidle=800, busy=150 → 150/950*100
        #expect(abs(sample.cpuPercent - (150.0 / 950.0 * 100.0)) < 0.001)
        #expect(sample.memUsedBytes == (1024000 - 256000) * 1024)
        #expect(sample.memTotalBytes == 1024000 * 1024)
        // lo excluded; rates over 2s
        #expect(sample.netRxBytesPerSec == 1000)
        #expect(sample.netTxBytesPerSec == 1500)
        // vda only (vda1 partition excluded); sectors*512 over 2s
        #expect(sample.diskReadBytesPerSec == Double((300 - 100) * 512) / 2.0)
        #expect(sample.diskWriteBytesPerSec == Double((400 - 200) * 512) / 2.0)
    }

    @Test func garbageFrameReturnsNil() {
        #expect(ProcStatsParser.parseFrame("garbage\nno markers", at: Date()) == nil)
    }

    @Test func clampsCounterResets() {
        // If counters go backwards (container restart), rates clamp to 0 rather than wrap.
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1002)
        let high = ProcStatsSnapshot(
            timestamp: t0, cpuTotal: 1000, cpuIdle: 900,
            memTotalBytes: 1024, memAvailableBytes: 512,
            netRxBytes: 5000, netTxBytes: 5000,
            diskReadBytes: 5000, diskWriteBytes: 5000
        )
        let low = ProcStatsSnapshot(
            timestamp: t1, cpuTotal: 100, cpuIdle: 90,
            memTotalBytes: 1024, memAvailableBytes: 512,
            netRxBytes: 10, netTxBytes: 10,
            diskReadBytes: 10, diskWriteBytes: 10
        )
        let sample = ProcStatsParser.sample(from: high, to: low)
        #expect(sample.cpuPercent == 0)
        #expect(sample.netRxBytesPerSec == 0)
        #expect(sample.diskWriteBytesPerSec == 0)
    }
}
