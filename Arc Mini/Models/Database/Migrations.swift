//
//  Migrations.swift
//  Arc
//
//  Created by Matt Greenfield on 8/6/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB

class Migrations {

    static func addLocoKitMigrations(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("ArcTimelineItem") { db in
            try db.alter(table: "TimelineItem") { table in
                table.add(column: "activeEnergyBurned", .double)
                table.add(column: "averageHeartRate", .double)
                table.add(column: "maxHeartRate", .double)
                table.add(column: "hkStepCount", .double)
            }
        }

        migrator.registerMigration("ArcPath") { db in
            try db.alter(table: "TimelineItem") { table in
                table.add(column: "manualActivityType", .boolean).indexed()
                table.add(column: "unknownActivityType", .boolean).defaults(to: false)
                table.add(column: "uncertainActivityType", .boolean)
                table.add(column: "activityTypeConfidenceScore", .double)
            }
        }

        migrator.registerMigration("ArcVisit") { db in
            try db.alter(table: "TimelineItem") { table in
                table.add(column: "placeId", .text).indexed()
                table.add(column: "manualPlace", .boolean).indexed()
                table.add(column: "streetAddress", .text).indexed()
                table.add(column: "customTitle", .text).indexed()
                table.add(column: "swarmCheckinId", .text)
            }
        }

        migrator.registerMigration("Note") { db in
            try db.create(table: "Note") { table in
                table.column("noteId", .text).primaryKey()
                table.column("date", .datetime).notNull().indexed()
                table.column("lastSaved", .datetime).notNull().indexed()
                table.column("source", .text).notNull().indexed()
                table.column("body", .text).notNull().indexed()
                table.column("deleted", .boolean).notNull().indexed()
            }
        }

        migrator.registerMigration("TimelineItem.workoutRouteId") { db in
            try? db.alter(table: "TimelineItem") { table in
                table.add(column: "workoutRouteId", .text).indexed()
            }
        }
        
        migrator.registerMigration("Backups v2") { db in
            try? db.alter(table: "Note") { table in
                table.add(column: "backupLastSaved", .datetime).indexed()
            }
            try? db.alter(table: "TimelineItem") { table in
                table.add(column: "backupLastSaved", .datetime).indexed()
            }
            try? db.alter(table: "LocomotionSample") { table in
                table.add(column: "backupLastSaved", .datetime).indexed()
            }
        }
    }

    static func addLocoKitAuxiliaryMigrations(to migrator: inout DatabaseMigrator) {
        // none yet
    }

    /**
     * potentially time expensive, so need to be done backgrounded, post launch
     */
    static func addDelayedLocoKitMigrations(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Backups v2 samples index") { db in
            try db.create(index: "LocomotionSample_on_backupLastSaved_lastSaved", on: "LocomotionSample",
                          columns: ["backupLastSaved", "lastSaved"])
        }
    }
    
    static func addArcMigrations(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Place") { db in
            try db.create(table: "Place") { table in
                table.column("placeId", .text).primaryKey()
                table.column("lastSaved", .datetime).notNull().indexed()
                table.column("needsUpdate", .boolean).indexed()

                table.column("name", .text).notNull().indexed()
                table.column("foursquareVenueId", .text).indexed()
                table.column("facebookPlaceId", .text).indexed()
                table.column("movesPlaceId", .integer).indexed()
                table.column("isHome", .boolean)

                table.column("foursquareCategoryId", .text)

                table.column("latitude", .double).notNull().indexed()
                table.column("longitude", .double).notNull()
                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()

                table.column("visitsCount", .integer).notNull().indexed().defaults(to: 0)
                table.column("visitDays", .integer).notNull().defaults(to: 0)

                table.column("averageSteps", .integer)
                table.column("averageCalories", .double)
                table.column("averageHeartRate", .double)
                table.column("averageMaxHeartRate", .double)

                table.column("startTimesHistogram", .text)
                table.column("endTimesHistogram", .text)
                table.column("durationsHistogram", .text)
                table.column("coordinatesMatrix", .text)
                table.column("coordinatesMatrixBlob", .blob)
                table.column("visitTimesHistograms", .text)
            }

            try db.create(index: "Place_on_longitude_latitude", on: "Place", columns: ["longitude", "latitude"])
        }

        migrator.registerMigration("TrackPlay") { db in
            try? db.create(table: "TrackPlay") { table in
                table.column("date", .datetime).primaryKey()
                table.column("name", .text).notNull().indexed()
                table.column("artist", .text).indexed()
            }
        }
        
        migrator.registerMigration("Place FlatBuffers") { db in
            try? db.alter(table: "Place") { table in
                table.add(column: "coordinatesMatrixBlob", .blob)
            }
        }
    }

}
