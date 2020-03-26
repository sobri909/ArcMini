//
//  ArcError.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 11/08/16.
//  Copyright © 2016 Big Paua. All rights reserved.
//

import Foundation

enum ArcErrorCode: Int {
    case nilDateRange
    case healthKitError
    case missingUserID
    case missingCKRecord
    case modifyingCKRecordWhileSaving
    case alreadySavingCKRecord
    case foursquareTokenMissing
    case foursquareTokenInvalid
    case foursquareRateLimited
}

class ArcError: NSError {
    
    static let domain = "ArcError"
    
    init(code: ArcErrorCode, description: String?) {
        var userInfo: [String: Any] = [:]
        
        if let description = description {
            userInfo[NSLocalizedDescriptionKey] = description
        }
        
        super.init(domain: ArcError.domain, code: code.rawValue, userInfo: userInfo)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var errorCode: ArcErrorCode {
        return ArcErrorCode(rawValue: code)!
    }
    
}
