import Foundation
import os

enum ErrorLogger {
    private static let logger = Logger(subsystem: "sg.tsc.EVAi2", category: "Error")
    private static let logFileName = "evai-errors.log"
    private static let maxLogFileBytes = 512_000

    enum Category: String {
        case extraction
        case storage
        case network
        case database
        case image
        case background
        case security
        case general
    }

    static func log(
        _ message: String,
        category: Category = .general,
        error: Error? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let detail = error.map { " | \($0.localizedDescription)" } ?? ""
        let entry = "[\(category.rawValue)] \(message)\(detail) (\(fileName):\(line))"
        logger.error("\(entry, privacy: .public)")
        appendToFile(entry)
    }

    static func recentEntries(limit: Int = 50) -> [String] {
        guard let url = logFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .suffix(limit)
            .map { String($0) }
    }

    static func clearLog() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static var logFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(logFileName)
    }

    private static func appendToFile(_ entry: String) {
        guard let url = logFileURL else { return }
        let line = "\(ISO8601DateFormatter().string(from: .now)) \(entry)\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
            trimLogIfNeeded(at: url)
        } else {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func trimLogIfNeeded(at url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int,
              size > maxLogFileBytes,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        let trimmed = content.components(separatedBy: "\n").suffix(200).joined(separator: "\n")
        try? trimmed.write(to: url, atomically: true, encoding: .utf8)
    }
}
