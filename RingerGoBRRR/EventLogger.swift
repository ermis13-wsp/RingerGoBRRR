import Foundation

// MARK: - Log entry kinds

enum LogEntryKind {
    case sample
    case stateChange
    case calibration
    case error
    case info
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let kind: LogEntryKind
    let message: String

    var formattedTimestamp: String {
        LogEntry.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var plainText: String {
        "\(formattedTimestamp)  \(message)"
    }
}

// MARK: - EventLogger

final class EventLogger: ObservableObject {

    @Published private(set) var entries: [LogEntry] = []

    private let maxEntries = 1000

    // MARK: - Logging helpers

    func logSample(_ ms: Double, state: RingerState) {
        let msg = String(format: "SAMPLE  %.1f ms  [%@]", ms, state.rawValue)
        append(kind: .sample, message: msg)
    }

    func logStateChange(from old: RingerState, to new: RingerState) {
        let msg = "STATE CHANGED  \(old.rawValue) → \(new.rawValue)"
        append(kind: .stateChange, message: msg)
    }

    func logCalibration(_ message: String) {
        append(kind: .calibration, message: "CALIBRATION  \(message)")
    }

    func logError(_ message: String) {
        append(kind: .error, message: "ERROR  \(message)")
    }

    func logInfo(_ message: String) {
        append(kind: .info, message: message)
    }

    // MARK: - Core append

    private func append(kind: LogEntryKind, message: String) {
        let entry = LogEntry(timestamp: Date(), kind: kind, message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    // MARK: - Export

    func exportText() -> String {
        var lines: [String] = []
        lines.append("=== RINGER GO BRRR — Event Log ===")
        lines.append("Exported: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("DISCLAIMER: This log reflects heuristic inferences based on")
        lines.append("audio completion timing. iOS does NOT officially expose the")
        lines.append("Ring/Silent switch state to third-party apps.")
        lines.append(String(repeating: "-", count: 50))
        lines.append("")
        for entry in entries {
            lines.append(entry.plainText)
        }
        return lines.joined(separator: "\n")
    }

    func clear() {
        entries.removeAll()
    }
}
