//
//  DebugLogger.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 8/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

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

    func handle(_ formattedLogLine: String) {
        print(formattedLogLine)
    }

}
