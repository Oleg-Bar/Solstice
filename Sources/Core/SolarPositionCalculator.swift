import Foundation
import simd

public struct SolarPosition: Sendable {
    public let latitude: Double
    public let longitude: Double
    public var direction: SIMD3<Double> { GlobeGeometry.position(latitude: latitude, longitude: longitude) }
}

public enum SolarPositionCalculator {
    /// NOAA fractional-year approximation, UTC. Longitude is east-positive.
    public static func position(at date: Date) -> SolarPosition {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date)!)
        let days = Double(calendar.range(of: .day, in: .year, for: date)!.count)
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hour = Double(c.hour!) + Double(c.minute!) / 60 + Double(c.second!) / 3600
        let gamma = 2 * Double.pi / days * (day - 1 + (hour - 12) / 24)
        let equation = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let longitude = normalizedLongitude(180 - hour * 15 - equation / 4)
        return SolarPosition(latitude: declination * 180 / .pi, longitude: longitude)
    }
    public static func normalizedLongitude(_ value: Double) -> Double {
        let positive = (value + 180).truncatingRemainder(dividingBy: 360)
        return (positive < 0 ? positive + 360 : positive) - 180
    }
}

public enum LunarPhaseCalculator {
    /// Mean synodic month; approximate phase, not a lunar ephemeris.
    public static func angle(at date: Date) -> Double {
        let referenceNewMoon = 947182440.0 // 2000-01-06 18:14 UTC
        let cycle = (date.timeIntervalSince1970 - referenceNewMoon) / (29.530588853 * 86400)
        return (cycle - floor(cycle)) * 2 * .pi
    }
    public static func illumination(at date: Date) -> Double { (1 - cos(angle(at: date))) / 2 }
}
