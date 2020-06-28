//
//  DebugLogger.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 8/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import os.log
import Logging
import LoggingFormatAndPipe
import Combine

let logger = Logger(label: "com.bigpaua.ArcMini.main") { _ in
    return LoggingFormatAndPipe.Handler(
        formatter: DebugLogger.LogDateFormatter(),
        pipe: DebugLogger.highlander
    )
}

class DebugLogger: LoggingFormatAndPipe.Pipe, ObservableObject {

    static let highlander = DebugLogger()

    public let objectWillChange = ObservableObjectPublisher()

    private init() {
        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            os_log("COULDN'T CREATE LOGS DIR", type: .error)
        }
    }

    func handle(_ formattedLogLine: String) {
        onMain {
            do {
                try formattedLogLine.appendLineToURL(fileURL: self.sessionLogFileURL)
            } catch {
                os_log("COULDN'T WRITE TO FILE", type: .error)
            }
            print(formattedLogLine)
        }
    }

    func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        onMain { self.objectWillChange.send() }
    }

    // MARK: -

    private(set) lazy var sessionLogFileURL: URL = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let filename = formatter.string(from: Date())
        return logsDir.appendingPathComponent(filename + ".log")
    }()

    var logsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last!
        return dir.appendingPathComponent("Logs", isDirectory: true)
    }

    var logFileURLs: [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: logsDir,
                                                                    includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])
            return files
                .filter { !$0.hasDirectoryPath && $0.pathExtension.lowercased() == "log" }
                .sorted { $0.path > $1.path }

        } catch {
            logger.error("\(error)")
            return []
        }
    }

    class LogDateFormatter: LoggingFormatAndPipe.Formatter {
        var timestampFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter
        }()

        func processLog(level: Logging.Logger.Level, message: Logging.Logger.Message, prettyMetadata: String?, file: String, function: String, line: UInt) -> String {
            if level == .error {
                return String(format: "[%@] [ERROR] \(message)", self.timestampFormatter.string(from: Date()))
            }
            return String(format: "[%@] \(message)", self.timestampFormatter.string(from: Date()))
        }
    }

}
