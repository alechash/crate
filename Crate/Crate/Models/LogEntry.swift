import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let source: String
    let message: String
    let level: Level

    enum Level: String {
        case info, warning, error

        var color: Color {
            switch self {
            case .info: .secondary
            case .warning: .orange
            case .error: .red
            }
        }
    }

    var formattedTime: String {
        Self.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
