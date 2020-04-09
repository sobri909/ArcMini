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

let logger = Logger(label: "com.bigpaua.ArcMini.main") { _ in
    return LoggingFormatAndPipe.Handler(
        formatter: BasicFormatter.adorkable,
        pipe: DebugLogger.highlander
    )
}

class DebugLogger: LoggingFormatAndPipe.Pipe {

    static let highlander = DebugLogger()

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

    // MARK: -

    private lazy var sessionLogFileURL: URL = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd.HHmm"
        let filename = formatter.string(from: Date())
        return logsDir.appendingPathComponent(filename + ".log")
    }()

    private var logsDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last!
        return dir.appendingPathComponent("Logs", isDirectory: true)
    }

}
