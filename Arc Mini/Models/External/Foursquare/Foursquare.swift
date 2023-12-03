//
// Created by Matt Greenfield on 8/03/16.
// Copyright (c) 2016 Big Paua. All rights reserved.
//

import UIKit
import SwiftNotes
import PromiseKit
import CoreLocation

extension NSNotification.Name {
    static let foursquareAuthenticated = Notification.Name("foursquareAuthenticated")
}

class Foursquare {

    // MARK: - Fetch places (v3 API)

    static func fetchPlaces(for location: CLLocation, query: String? = nil) -> Promise<[Place]?> {
        return Promise { seal in
            guard let apiKey = Settings.foursquareAPIKey else { seal.fulfill(nil); return }

            var urlString = "https://api.foursquare.com/v3/places"

            if query == nil || query?.isEmpty == true {
                urlString += "/nearby"
            } else {
                urlString += "/search"
            }

            urlString += String(format: "?limit=50&ll=%f,%f", location.coordinate.latitude, location.coordinate.longitude)

            if let query, query.count > 0, let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                urlString += "&query=\(encoded)"
            }

            // authed user?
            if let token = Settings.highlander[.foursquareToken] as? String {
                urlString += String(format: "&oauth_token=%@", token)
            }

            guard let url = URL(string: urlString) else {
                seal.fulfill(nil)
                return
            }

            var request = URLRequest(url: url)
            request.addValue(apiKey, forHTTPHeaderField: "Authorization")

            if let languageCode = Locale.preferredLanguages.first {
                request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                    return
                }

                if let error = handle(response: response) {
                    logger.error("\(error)")
                }

                guard let data = data else {
                    seal.fulfill(nil)
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(PlacesSearchResult.self, from: data)
                    seal.fulfill(result.results)

                } catch {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                }
            }
            
            task.resume()
        }
    }

    // MARK: - Fetch venues (v2 API)

    static func fetchVenues(for location: CLLocation, query: String? = nil) -> Promise<[Venue]?> {
        return Promise { seal in
            guard let clientId = Settings.foursquareClientId else { seal.fulfill(nil); return }
            guard let clientSecret = Settings.foursquareClientSecret else { seal.fulfill(nil); return }

            var urlString = "https://api.foursquare.com/v2/venues/search"

            // api version
            urlString += "?v=20181201&m=swarm"

            // authed user?
            if let token = Settings.highlander[.foursquareToken] as? String {
                urlString += String(format: "&oauth_token=%@", token)
            } else { // not authed
                urlString += String(format: "&client_id=%@&client_secret=%@", clientId, clientSecret)
            }

            urlString += String(format: "&ll=%f,%f", location.coordinate.latitude, location.coordinate.longitude)

            if let query = query, query.count > 0, let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                urlString += "&query=\(encoded)"
            }

            guard let url = URL(string: urlString) else {
                seal.fulfill(nil)
                return
            }

            var request = URLRequest(url: url)
            if let languageCode = Locale.preferredLanguages.first {
                request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                    return
                }

                if let error = handle(response: response) {
                    logger.error("\(error)")
                }

                guard let data = data else {
                    seal.fulfill(nil)
                    return
                }

                do {
                    let result = try JSONDecoder().decode(VenuesSearchResult.self, from: data)
                    seal.fulfill(result.response?.venues)

                } catch {
                    logger.error("\(error)")
                    seal.fulfill(nil)
                }
            }

            task.resume()
        }
    }

    private static func handle(response: URLResponse?) -> Error? {
        guard let response = response as? HTTPURLResponse else { return nil }
        if response.statusCode == 401 { // invalid token
            logger.info("INVALID FOURSQUARE TOKEN")
            Settings.highlander[.foursquareToken] = nil
            return ArcError(code: .foursquareTokenInvalid, description: "Invalid Foursquare token")
        }
        if response.statusCode == 429 { // rate limited!
            logger.info("FOURSQUARE RATE LIMITED")
            return ArcError(code: .foursquareRateLimited, description: "Foursquare rate limited")
        }
        return nil
    }

    // MARK: -

    static func processCallback(url: URL) {
        guard let clientId = Settings.foursquareClientId else { return }
        guard let clientSecret = Settings.foursquareClientId else { return }

        guard url.host == "foursquare" else { return }
        guard let query = url.query, !query.isEmpty else { return }
        guard let parts = url.queryPairs else { return }
        guard let code = parts["code"] else { return }

        FSOAuth.shared().requestAccessToken(forCode: code, clientId: clientId, callbackURIString: "arcapp://foursquare",
                                            clientSecret: clientSecret)
        { token, requestCompleted, errorCode in
            guard let token = token, !token.isEmpty else {
                logger.error("errorCode: \(errorCode.rawValue)")
                return
            }
            logger.debug("TOKEN: \(token)")
            Settings.highlander[.foursquareToken] = token
            onMain { trigger(.foursquareAuthenticated) }
        }
    }

    // MARK: - Venue responses (v3 API)

    struct PlacesSearchResult: Decodable {
        var results: [Place]
    }

    struct Place: Decodable {
        var id: String
        var name: String
        var geocodes: [String: Geocode]
        var categories: [Category]

        var primaryCategory: Category? {
            return categories.first { $0.primary != false }
        }

        var location: CLLocation? {
            return geocodes["main"]?.clLocation
        }

        struct Geocode: Decodable {
            var latitude: CLLocationDegrees
            var longitude: CLLocationDegrees
            var clLocation: CLLocation {
                return CLLocation(latitude: latitude, longitude: longitude)
            }
        }

        struct Category: Decodable {
            var id: Int
            var name: String
            var primary: Bool?
        }

        enum CodingKeys: String, CodingKey {
            case id = "fsq_id"
            case name
            case categories
            case geocodes
        }
    }

    // MARK: - Venue responses (v2 API)

    struct VenuesSearchResult: Decodable {
        var response: Response?

        struct Response: Decodable {
            var venues: [Venue]
        }
    }

    struct Venue: Decodable {
        var id: String
        var name: String
        var location: Location
        var categories: [Category]

        var primaryCategory: Category? {
            return categories.first { $0.primary }
        }

        struct Location: Decodable {
            var lat: CLLocationDegrees
            var lng: CLLocationDegrees
            var clLocation: CLLocation {
                return CLLocation(latitude: lat, longitude: lng)
            }
        }

        struct Category: Decodable {
            var id: String
            var name: String
            var primary: Bool
        }
    }

}

// MARK: - Venue category icons

extension UIImage {

    // https://developer.foursquare.com/docs/categories
    convenience init(foursquareCategoryIntId: Int) {
        switch foursquareCategoryIntId {
        default:
            self.init(named: "defaultPlaceIcon24")!
        }
    }

    // https://developer.foursquare.com/docs/resources/categories
    convenience init(foursquareCategoryId: String) {
        switch foursquareCategoryId {

            // homes
        case "4e67e38e036454776db1fb3a", "5032891291d4c4b30a586d68", "4bf58dd8d48988d103941735", "4f2a210c4b9023bd5841ed28",
             "4d954b06a243a5684965b473", "52f2ab2ebcbc57f1066b8b55":
            self.init(named: "homeIcon")!

            // fast food
        case "4bf58dd8d48988d120951735", "56aa371be4b08b9a8d57350b", "4bf58dd8d48988d1cb941735", "4bf58dd8d48988d16e941735",
             "4bf58dd8d48988d10b941735", "4bf58dd8d48988d16c941735", "52f2ab2ebcbc57f1066b8b41", "4bf58dd8d48988d1c5941735":
            self.init(named: "fastfoodIcon24")!

            // cafes
        case "4bf58dd8d48988d1e0931735", "4bf58dd8d48988d16d941735", "54135bf5e4b08f3d2429dfe7", "5665c7b9498e7d8a4f2c0f06":
            self.init(named: "cafeIcon24")!

            // restaurants
        case "4bf58dd8d48988d1d0941735", "4eb1bc533b7b2c5b1d4306cb", "54f4ba06498e2cf5561da814", "4bf58dd8d48988d1ef931735",
             "4bf58dd8d48988d1a1941735", "503288ae91d4c4b30a586d67", "4bf58dd8d48988d14e941735", "4bf58dd8d48988d149941735",
             "56aa371be4b08b9a8d573502", "52af39fb3cf9994f4e043be9", "4bf58dd8d48988d14a941735", "4bf58dd8d48988d143941735",
             "4bf58dd8d48988d113941735", "4bf58dd8d48988d111941735", "55a59bace4b013909087cb15", "55a59bace4b013909087cb24",
             "4bf58dd8d48988d1d2941735", "4bf58dd8d48988d110941735", "4bf58dd8d48988d1c4941735", "4bf58dd8d48988d145941735",
             "4bf58dd8d48988d142941735":
            self.init(named: "restaurantIcon")!

            // bars
        case "4bf58dd8d48988d11e941735", "4bf58dd8d48988d1e7931735", "4bf58dd8d48988d1e8931735", "4bf58dd8d48988d11b941735",
             "4bf58dd8d48988d116941735", "4bf58dd8d48988d11c941735":
            self.init(named: "barIcon24")!

            // hotels
        case "4bf58dd8d48988d1fa931735", "4bf58dd8d48988d1f8931735", "4f4530a74b9074f6e4fb0100", "4bf58dd8d48988d1ee931735",
             "5bae9231bedf3950379f89cb", "4bf58dd8d48988d1fb931735", "4bf58dd8d48988d12f951735", "56aa371be4b08b9a8d5734e1",
             "4bf58dd8d48988d1a3941735":
            self.init(named: "hotelIcon")!

            // laundry
        case "4bf58dd8d48988d1fc941735":
            self.init(named: "laundryIcon")!

            // pizza
        case "4bf58dd8d48988d1ca941735":
            self.init(named: "pizzaIcon")!

            // shops that probably don't have trolleys
        case "4bf58dd8d48988d128951735", "4bf58dd8d48988d1fb941735", "52f2ab2ebcbc57f1066b8b25", "52f2ab2ebcbc57f1066b8b2b",
             "52f2ab2ebcbc57f1066b8b1e", "52f2ab2ebcbc57f1066b8b29", "52c71aaf3cf9994f4e043d17", "4bf58dd8d48988d1ff941735",
             "4f04afc02fb6e1c99f3db0bc", "4bf58dd8d48988d1fe941735", "4f04aa0c2fb6e1c99f3db0b8", "4d954afda243a5684865b473",
             "52f2ab2ebcbc57f1066b8b2f", "4bf58dd8d48988d121951735", "52f2ab2ebcbc57f1066b8b34", "52f2ab2ebcbc57f1066b8b3d":
            self.init(named: "shopIcon24")!

            // shops that might have trolleys
        case "4bf58dd8d48988d1f9941735", "5370f356bcbc57f1066c94c2", "4bf58dd8d48988d1f5941735", "4bf58dd8d48988d118951735",
             "50aa9e744b90af0d42d5de0e", "58daa1558bbb0b01f18ec1e8", "4bf58dd8d48988d186941735", "52f2ab2ebcbc57f1066b8b45",
             "52f2ab2ebcbc57f1066b8b46", "4bf58dd8d48988d119951735", "52f2ab2ebcbc57f1066b8b1c", "4bf58dd8d48988d1f8941735",
             "55888a5a498e782e3303b43a", "4eb1c0253b7b52c0e1adc2e9", "4bf58dd8d48988d1f6941735",  "52f2ab2ebcbc57f1066b8b42":
            self.init(named: "supermarketIcon24")!

        case "4bf58dd8d48988d175941735", "52f2ab2ebcbc57f1066b8b47", "503289d391d4c4b30a586d6a", "52f2ab2ebcbc57f1066b8b48",
             "4bf58dd8d48988d176941735", "58daa1558bbb0b01f18ec203", "4bf58dd8d48988d1b2941735":
            self.init(named: "gymIcon24")!

        case "52f2ab2ebcbc57f1066b8b49", "56aa371be4b08b9a8d57355e", "4e4c9077bd41f78e849722f9":
            self.init(named: "cyclingIcon24")!

        case "4bf58dd8d48988d105941735", "52e81612bcbc57f1066b7a44", "4bf58dd8d48988d15e941735":
            self.init(named: "swimmingIcon24")!

        case "4bf58dd8d48988d102941735", "4bf58dd8d48988d1ed941735", "52f2ab2ebcbc57f1066b8b3c", "58daa1558bbb0b01f18ec1ae":
            self.init(named: "spaIcon24")!

        case "4bf58dd8d48988d167941735", "5bae9231bedf3950379f89d2":
            self.init(named: "skateboardingIcon24")!

        case "4bf58dd8d48988d168941735", "52e81612bcbc57f1066b79e9":
            self.init(named: "inlineSkatingIcon24")!

        case "52e81612bcbc57f1066b79eb", "4bf58dd8d48988d1e6941735", "58daa1558bbb0b01f18ec1b0":
            self.init(named: "golfIcon24")!

        case "4bf58dd8d48988d124941735", "4bf58dd8d48988d127941735", "4bf58dd8d48988d174941735", "4bf58dd8d48988d125941735":
            self.init(named: "workIcon24")!

        case "4bf58dd8d48988d129951735", "4f4531504b9074f6e4fb0102", "4bf58dd8d48988d12a951735", "4bf58dd8d48988d1fd931735":
            self.init(named: "trainIcon24")!

        case "4bf58dd8d48988d1fe931735", "52f2ab2ebcbc57f1066b8b4f", "4bf58dd8d48988d12b951735":
            self.init(named: "busIcon24")!

        case "52f2ab2ebcbc57f1066b8b50", "4bf58dd8d48988d1ec931735", "52f2ab2ebcbc57f1066b8b51", "4bf58dd8d48988d1fc931735":
            self.init(named: "tramIcon24")!

        case "4bf58dd8d48988d130951735", "53fca564498e1a175f32528b", "4bf58dd8d48988d1ef941735":
            self.init(named: "carIcon24")!

        case "56aa371be4b08b9a8d57353e", "4e74f6cabd41c4836eac4c31", "55077a22498e5e9248869ba2", "4bf58dd8d48988d12d951735",
             "5744ccdfe4b0c0459246b4c1":
            self.init(named: "boatIcon24")!

        case "4bf58dd8d48988d1f7931735":
            self.init(named: "airplaneIcon24")!

        case "4bf58dd8d48988d1ed931735", "4bf58dd8d48988d1eb931735", "56aa371be4b08b9a8d57352f", "4bf58dd8d48988d1f0931735":
            self.init(named: "airportIcon24")!

        case "56aa371be4b08b9a8d573566":
            self.init(named: "skiingIcon24")!

        case "4bf58dd8d48988d1fd941735":
            self.init(named: "mallIcon24")!

        case "4bf58dd8d48988d163941735":
            self.init(named: "parkIcon24")!

        case "4bf58dd8d48988d113951735":
            self.init(named: "petrolStationIcon24")!

        case "4bf58dd8d48988d10a951735", "4bf58dd8d48988d126941735":
            self.init(named: "bankIcon24")!

        case "4c38df4de52ce0d596b336e1":
            self.init(named: "parkingIcon24")!

        case "4bf58dd8d48988d196941735", "4bf58dd8d48988d177941735", "4bf58dd8d48988d104941735", "4bf58dd8d48988d178941735":
            self.init(named: "hospitalIcon24")!

        case "4bf58dd8d48988d110951735": // Salon / Barbershop
            self.init(named: "cutIcon24")!

        case "4bf58dd8d48988d130941735", "4eb1bea83b7b6f98df247e06":
            self.init(named: "buildingIcon24")!

        case "4bf58dd8d48988d172941735": // post office
            self.init(named: "letterIcon24")!

        case "5032833091d4c4b30a586d60": // motorcycle shop
            self.init(named: "motorcycleIcon24")!

        case "4bf58dd8d48988d112951735":
            self.init(named: "spannerIcon24")!

        case "4bf58dd8d48988d1e7941735": // playground
            self.init(named: "childIcon24")!

        case "5745c2e4498e11e7bccabdbd", "4bf58dd8d48988d10f951735":
            self.init(named: "pharmacyIcon24")!

        case "4bf58dd8d48988d114951735", "4bf58dd8d48988d12f941735":
            self.init(named: "bookIcon24")!

        case "4d954b0ea243a5684a65b473", "52dea92d3cf9994f4e043dbb":
            self.init(named: "basketIcon24")!

        case "4bf58dd8d48988d122951735":
            self.init(named: "electronicsIcon24")!

        case "4bf58dd8d48988d124951735":
            self.init(named: "carIcon24")!

        case "4f4533804b9074f6e4fb0105", "4bf58dd8d48988d13b941735", "4bf58dd8d48988d1ae941735", "4bf58dd8d48988d13d941735":
            self.init(named: "schoolIcon24")!

        default:
            self.init(named: "defaultPlaceIcon24")!
        }
    }
}
