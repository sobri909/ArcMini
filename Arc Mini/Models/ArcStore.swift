//
//  ArcStore.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 12/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import GRDB
import LocoKit

class ArcStore: TimelineStore {

    // MARK: - Object creation

    override func createVisit(from sample: PersistentSample) -> ArcVisit {
        let visit = ArcVisit(in: self)
        visit.add(sample)
        return visit
    }

    override func createPath(from sample: PersistentSample) -> ArcPath {
        let path = ArcPath(in: self)
        path.add(sample)
        return path
    }

    override func createVisit(from samples: [PersistentSample]) -> ArcVisit {
        let visit = ArcVisit(in: self)
        visit.add(samples)
        return visit
    }

    override func createPath(from samples: [PersistentSample]) -> ArcPath {
        let path = ArcPath(in: self)
        path.add(samples)
        return path
    }

    override func item(for row: Row) -> TimelineItem {
        guard let itemId = row["itemId"] as String? else { fatalError("MISSING ITEMID") }
        if let item = object(for: UUID(uuidString: itemId)!) as? TimelineItem { return item }
        guard let isVisit = row["isVisit"] as Bool? else { fatalError("MISSING ISVISIT BOOL") }
        return isVisit ? ArcVisit(from: row.asDict(in: self), in: self) : ArcPath(from: row.asDict(in: self), in: self)
    }

}
