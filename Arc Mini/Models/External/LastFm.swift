//
//  LastFm.swift
//  Arc
//
//  Created by Matt Greenfield on 30/5/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import LocoKit
import PromiseKit

class LastFm {

    static let apiRoot = "https://ws.audioscrobbler.com/2.0/"
    static var lastImportDate: Date?

//    static func importPlayedTracks() {
//        guard AppDelegate.reachability.connection == .wifi else { return }
//        guard let username = Settings.highlander[.lastFmUsername] as? String else { return }
//
//        if let lastImportDate = lastImportDate, lastImportDate.age < 60 * 5 { return }
//        lastImportDate = Date()
//
//        Jobs.addSecondaryJob("importPlayedTracks", dontDupe: true) {
//            guard AppDelegate.reachability.connection == .wifi else { return }
//
//            var fromDate = Settings.firstDate
//            if let lastDate = Settings.highlander[.lastLastFmTrackDate] as? Date {
//                fromDate = lastDate
//            }
//
//            LastFm.fetchPlayedTracks(for: username, from: fromDate).done { results in
//                guard let tracks = results?.recenttracks.track else { return }
//
//                var plays: [TrackPlay] = []
//                for track in tracks {
//                    if let play = TrackPlay(track: track), play.date.timeIntervalSince(fromDate) > 0 {
//                        log("PLAY: \(play.name), \(play.date.dayTimeLogString)")
//                        plays.append(play)
//                    }
//                }
//                if plays.isEmpty { return }
//
//                do {
//                    try Stalker.store.arcPool.write { db in
//                        for play in plays {
//                            try play.save(db)
//                        }
//                    }
//                    log("SAVED PLAYS: \(plays.count)")
//                    if let date = plays.first?.date {
//                        Settings.highlander[.lastLastFmTrackDate] = date
//                    }
//
//                } catch {
//                    logger.error("\(error)")
//                }
//
//            }.cauterize()
//        }
//    }

    static func fetchPlayedTracks(for username: String, from: Date, to: Date? = nil) -> Promise<RecentTracksResponse?> {
        return Promise { seal in
            guard let apiKey = Settings.lastFmAPIKey else { seal.fulfill(nil); return }

            var urlString = apiRoot + "?format=json&api_key=" + apiKey
            urlString += "&method=user.getRecentTracks&user=" + username
            urlString += String(format: "&from=%.0f", from.timeIntervalSince1970)
            if let to = to { urlString += String(format: "&to=%.0f", to.timeIntervalSince1970) }

            guard let url = URL(string: urlString) else { seal.fulfill(nil); return }

            let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
                if let error = error {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                    return
                }

                guard let data = data else {
                    seal.fulfill(nil)
                    return
                }

                do {
                    let result = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
                    seal.fulfill(result)

                } catch {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                }
            }

            task.resume()
        }
    }

    struct RecentTracksResponse: Decodable {
        var recenttracks: RecentTracks

        struct RecentTracks: Decodable {
            var track: [Track]
        }
    }

    struct Track: Decodable {
        var mbid: String?
        var name: String
        var artist: Artist?
        var album: Album?
        var date: APIDate?
    }

    struct APIDate: Decodable {
        var uts: String
        
        var date: Date? {
            guard let timeInterval = TimeInterval(uts) else { return nil }
            return Date(timeIntervalSince1970: timeInterval)
        }
    }

    struct Artist: Decodable {
        var mbid: String?
        var name: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.mbid = try? container.decode(String.self, forKey: .mbid)
            self.name = try container.decode(String.self, forKey: .name)
        }

        private enum CodingKeys: String, CodingKey {
            case mbid
            case name = "#text"
        }
    }

    struct Album: Decodable {
        var mbid: String?
        var name: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.mbid = try? container.decode(String.self, forKey: .mbid)
            self.name = try container.decode(String.self, forKey: .name)
        }

        private enum CodingKeys: String, CodingKey {
            case mbid
            case name = "#text"
        }
    }

}
