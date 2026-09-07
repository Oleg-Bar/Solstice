import Foundation
import simd

public struct City: Identifiable, Codable, Sendable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    /// Stable across system-language changes; the localized display name is not identity.
    public var id: String { "\(latitude)|\(longitude)|\(timeZoneIdentifier)" }
    public var position: SIMD3<Double> { GlobeGeometry.position(latitude: latitude, longitude: longitude) }
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier)! }
    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        precondition((-90...90).contains(latitude) && (-180...180).contains(longitude), "Invalid city coordinates")
        precondition(TimeZone(identifier: timeZoneIdentifier) != nil, "Invalid IANA time zone")
        self.name = name; self.latitude = latitude; self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public enum CitiesConfiguration {
    public static func including(observer: ObserverLocation, additional: [City] = []) -> [City] {
        including(observer: observer,selection: cities+additional)
    }
    public static func including(observer: ObserverLocation,selection: [City]) -> [City] {
        let current = City(name: SystemCityCatalog.localizedCityName(for: observer.timeZoneIdentifier),
            latitude: observer.latitude,longitude: observer.longitude,timeZoneIdentifier: observer.timeZoneIdentifier)
        let others = selection.filter { !matchesObserver($0,observer: observer) }
        var unique: [City] = [current]
        for city in others where !unique.contains(where: { simd_length($0.position-city.position) < 0.015 }) {
            unique.append(city)
        }
        return unique
    }
    public static func matchesObserver(_ city: City,observer: ObserverLocation) -> Bool {
        let current = GlobeGeometry.position(latitude: observer.latitude,longitude: observer.longitude)
        return simd_length(city.position-current) < 0.015 && city.timeZoneIdentifier == observer.timeZoneIdentifier
    }
    public static var cities: [City] { [
        city(latitude: 40.4168,longitude: -3.7038,timeZoneIdentifier: "Europe/Madrid"),
        city(latitude: 1.3521,longitude: 103.8198,timeZoneIdentifier: "Asia/Singapore"),
        city(latitude: 40.7128,longitude: -74.0060,timeZoneIdentifier: "America/New_York")
    ] }
    private static func city(latitude: Double,longitude: Double,timeZoneIdentifier: String) -> City {
        City(name: SystemCityCatalog.localizedCityName(for: timeZoneIdentifier),latitude: latitude,
            longitude: longitude,timeZoneIdentifier: timeZoneIdentifier)
    }
}

public enum CityStore {
    private static let key = "customCities"
    private static let selectionKey = "selectedCitiesV2"
    private static var defaults: UserDefaults { UserDefaults(suiteName: "studio.terra.shared") ?? .standard }
    public static func load() -> [City] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let saved = (try? JSONDecoder().decode([City].self,from: data)) ?? []
        return saved.map { city in
            City(name: SystemCityCatalog.localizedCityName(for: city.timeZoneIdentifier),
                latitude: city.latitude,longitude: city.longitude,timeZoneIdentifier: city.timeZoneIdentifier)
        }
    }
    public static func save(_ cities: [City]) {
        guard let data = try? JSONEncoder().encode(cities) else { return }
        defaults.set(data,forKey: key)
    }
    /// Migrates the original fixed-city model into one editable selection.
    public static func loadSelection() -> [City] {
        if let data = defaults.data(forKey: selectionKey),
           let decoded = try? JSONDecoder().decode([City].self,from: data) {
            return localized(decoded)
        }
        return unique(CitiesConfiguration.cities+load())
    }
    public static func saveSelection(_ cities: [City]) {
        guard let data = try? JSONEncoder().encode(cities) else { return }
        defaults.set(data,forKey: selectionKey)
    }
    public static func removing(id: String,from cities: [City]) -> [City]? {
        guard let index = cities.firstIndex(where: { $0.id == id }) else { return nil }
        var updated = cities
        updated.remove(at: index)
        return updated
    }
    private static func localized(_ cities: [City]) -> [City] {
        cities.map { city in
            City(name: SystemCityCatalog.localizedCityName(for: city.timeZoneIdentifier),latitude: city.latitude,
                longitude: city.longitude,timeZoneIdentifier: city.timeZoneIdentifier)
        }
    }
    private static func unique(_ cities: [City]) -> [City] {
        var result: [City] = []
        for city in cities where !result.contains(where: { simd_length($0.position-city.position) < 0.015 }) {
            result.append(city)
        }
        return result
    }
}

public struct CityClockState: Sendable {
    public let hour: Int
    public let minute: Int
    public let second: Int
    public let day: Int
    public let isDaylight: Bool
    public var hourAngle: Double { (Double(hour % 12) + Double(minute) / 60) * .pi / 6 }
    public var minuteAngle: Double { (Double(minute) + Double(second) / 60) * .pi / 30 }
    public var meridiem: String { hour < 12 ? "AM" : "PM" }
    public var label: String { String(format: "%02d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minute, meridiem) }
    public init(city: City, date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let c = calendar.dateComponents([.hour, .minute, .second, .day], from: date)
        hour = c.hour!; minute = c.minute!; second = c.second!; day = c.day!
        isDaylight = simd_dot(city.position,SolarPositionCalculator.position(at: date).direction) > 0
    }
}
