//
//  WeatherAPI.swift
//  Aerial
//
//  Created by Guillaume Louel on 15/04/2020.
//  Copyright © 2020 Guillaume Louel. All rights reserved.
//

import Foundation
import OAuthSwift

struct Weather {
    static var info: Welcome?

    // MARK: - Welcome
    struct Welcome: Codable {
        let location: Location
        let currentObservation: CurrentObservation
        let forecasts: [Forecast]

        enum CodingKeys: String, CodingKey {
            case location
            case currentObservation = "current_observation"
            case forecasts
        }
    }

    // MARK: - CurrentObservation
    struct CurrentObservation: Codable {
        let wind: Wind
        let atmosphere: Atmosphere
        let astronomy: Astronomy
        let condition: Condition
        let pubDate: Int
    }

    // MARK: - Astronomy
    struct Astronomy: Codable {
        let sunrise, sunset: String
    }

    // MARK: - Atmosphere
    struct Atmosphere: Codable {
        let humidity: Double
        let visibility: Double
        let pressure: Double
        let rising: Int
    }

    // MARK: - Condition
    struct Condition: Codable {
        let text: String
        let code, temperature: Int
    }

    // MARK: - Wind
    struct Wind: Codable {
        let chill, direction: Int
        let speed: Double
    }

    // MARK: - Forecast
    struct Forecast: Codable {
        let day: String
        let date, low, high: Int
        let text: String
        let code: Int
    }

    // MARK: - Location
    struct Location: Codable {
        let city, region: String
        let woeid: Int
        let country: String
        let lat, long: Double
        let timezoneID: String

        enum CodingKeys: String, CodingKey {
            case city, region, woeid, country, lat, long
            case timezoneID = "timezone_id"
        }
    }

    static func fetch(failure: @escaping (_ error: OAuthSwiftError) -> Void,
                      success: @escaping (_ response: OAuthSwiftResponse) -> Void) {
        if testJson != "" {
            debugLog("=== YW: Starting JSON TEST MODE")
            let jsonData = testJson.data(using: .utf8)!
            info = try? newJSONDecoder().decode(Welcome.self, from: jsonData)
            if info != nil {
                let response = OAuthSwiftResponse.init(data: Data(), response: .init(), request: nil)
                success(response)   // Then the callback
            }

            return
        }

        if PrefsInfo.weather.locationMode == .useCurrent {
            let location = Locations.sharedInstance

            location.getCoordinates(failure: { (_) in
                failure(.cancelled) // Slightly naughty
            }, success: { (coordinates) in
                let lat = String(format: "%.2f", coordinates.latitude)
                let lon = String(format: "%.2f", coordinates.longitude)
                debugLog("=== YW: Starting locationMode")
                YahooWeatherAPI.shared.weather(lat: lat, lon: lon, failure: failure, success: { response in
                    debugLog("=== YW: API callback success")
                    processJson(response: response) // First we process
                    success(response)   // Then the callback
                }, unit: getDegree())
            })
        } else {
            // Just in case, we add a failsafe
            if PrefsInfo.weather.locationString == "" {
                PrefsInfo.weather.locationString = "Paris, FR"
            }
            debugLog("=== YW: Starting manual mode")
            YahooWeatherAPI.shared.weather(location: PrefsInfo.weather.locationString, failure: failure, success: { response in
                    debugLog("=== YW: API callback success")
                    processJson(response: response) // First we process
                    success(response)   // Then the callback
                }, unit: getDegree())
        }
    }

    static func processJson(response: OAuthSwiftResponse) {
        debugLog(response.dataString() ?? "=== YW: nil parsed data")

        info = try? newJSONDecoder().decode(Welcome.self, from: response.data)
        if info == nil {
            errorLog("Couldn't parse JSON, please report")
        }
    }

    static func getDegree() -> YahooWeatherAPIUnitType {
        if PrefsInfo.weather.degree == .celsius {
            return .metric
        } else {
            return .imperial
        }
    }

    // Day/night from provided sunset/sunrise time in the JSON Data
    static func isNight() -> Bool {
        if info == nil {
            return false    // We shouldn't be here but hey
        }

        // First we need to get today's date !
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: Date())

        // Apparently the string is always in am/pm format, in local time
        let pmformatter = DateFormatter()
        pmformatter.locale = Locale(identifier: "en_US_POSIX")
        pmformatter.dateFormat = "yyyy-MM-dd h:mm a"

        let sunrise = pmformatter.date(from: dateString + " " + info!.currentObservation.astronomy.sunrise)
        let sunset = pmformatter.date(from: dateString + " " + info!.currentObservation.astronomy.sunset)

        if sunrise == nil || sunset == nil {
            errorLog("Could not parse sunrise/sunset times, please report ! \(String(describing: sunrise)) \(String(describing: sunset))")
            errorLog(Date().debugDescription)
            errorLog(dateString + " " + info!.currentObservation.astronomy.sunrise)
            errorLog(dateString + " " + info!.currentObservation.astronomy.sunset)
            return false
        }

        let currentTime = Date()

        if currentTime > sunrise! && currentTime < sunset! {
            debugLog("=== YW: daytime")
            return false
        } else {
            debugLog("=== YW: nighttime")
            return true
        }
    }

    // Replace this with a sample json output to test
    static let testJson = ""
}
