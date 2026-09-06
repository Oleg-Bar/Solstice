import Foundation
import simd

public struct City: Identifiable, Sendable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public var id: String { "\(name)|\(latitude)|\(longitude)|\(timeZoneIdentifier)" }
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
    public static func including(observer: ObserverLocation) -> [City] {
        let current = City(name: observer.name,latitude: observer.latitude,longitude: observer.longitude,timeZoneIdentifier: observer.timeZoneIdentifier)
        let others = cities.filter {
            let sameName = $0.name.caseInsensitiveCompare(observer.name) == .orderedSame
            let nearby = simd_length($0.position-current.position) < 0.015 && $0.timeZoneIdentifier == observer.timeZoneIdentifier
            return !sameName && !nearby
        }
        return [current]+others
    }
    public static let cities: [City] = [
        City(name: "Madrid", latitude: 40.4168, longitude: -3.7038, timeZoneIdentifier: "Europe/Madrid"),
        City(name: "Singapore", latitude: 1.3521, longitude: 103.8198, timeZoneIdentifier: "Asia/Singapore"),
        City(name: "New York", latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York")
    ]
}

public struct CityClockState: Sendable {
    public let hour: Int
    public let minute: Int
    public let second: Int
    public let day: Int
    public var hourAngle: Double { (Double(hour % 12) + Double(minute) / 60) * .pi / 6 }
    public var minuteAngle: Double { (Double(minute) + Double(second) / 60) * .pi / 30 }
    public var meridiem: String { hour < 12 ? "AM" : "PM" }
    public var label: String { String(format: "%02d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minute, meridiem) }
    public init(city: City, date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let c = calendar.dateComponents([.hour, .minute, .second, .day], from: date)
        hour = c.hour!; minute = c.minute!; second = c.second!; day = c.day!
    }
}
