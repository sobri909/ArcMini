//
//  ArcDocument.swift
//  Arc
//
//  Created by Matt Greenfield on 22/11/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import Foundation

class ArcDocument: UIDocument {

    var data: Data?

    override func contents(forType typeName: String) throws -> Any {
        if let data = data { return data }
        if let data = try? Data(contentsOf: fileURL) {
            self.data = data
            return data
        }
        return Data()
    }

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let data = contents as? Data {
            self.data = data
        }
    }

}
