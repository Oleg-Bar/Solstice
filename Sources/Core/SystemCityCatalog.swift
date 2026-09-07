import Foundation

public struct SystemCityEntry: Hashable, Sendable {
    public let cityName: String
    public let countryName: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public var displayName: String { "\(cityName) — \(countryName)" }
    public var city: City {
        City(name: cityName,latitude: latitude,longitude: longitude,timeZoneIdentifier: timeZoneIdentifier)
    }
}

/// Reads the timezone city catalogue supplied by macOS itself.
public enum SystemCityCatalog {
    private static let systemURLs = [
        URL(fileURLWithPath: "/usr/share/zoneinfo/zone.tab"),
        URL(fileURLWithPath: "/var/db/timezone/zoneinfo/zone.tab")
    ]

    public static func load(locale: Locale = .current) -> [SystemCityEntry] {
        for url in systemURLs {
            if let text = try? String(contentsOf: url,encoding: .utf8) {
                let entries = parse(text,locale: locale)
                if !entries.isEmpty { return entries }
            }
        }
        return []
    }

    public static func parse(_ text: String,locale: Locale = .current) -> [SystemCityEntry] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            guard !line.hasPrefix("#") else { return nil }
            let columns = line.split(separator: "\t",omittingEmptySubsequences: false)
            guard columns.count >= 3,
                  let coordinate = parseISO6709(String(columns[1])) else { return nil }
            let identifier = String(columns[2])
            guard TimeZone(identifier: identifier) != nil else { return nil }
            let city = localizedCityName(for: identifier,locale: locale)
            let countryCode = String(columns[0]).split(separator: ",").first.map(String.init) ?? String(columns[0])
            let country = locale.localizedString(forRegionCode: countryCode) ?? countryCode
            return SystemCityEntry(cityName: city,countryName: country,latitude: coordinate.latitude,
                longitude: coordinate.longitude,timeZoneIdentifier: identifier)
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// Uses macOS' bundled CLDR data (`VVV`, exemplar city), so names follow the
    /// current system language without a network request or an app-owned dictionary.
    public static func localizedCityName(for timeZoneIdentifier: String,locale: Locale = .current) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return timeZoneIdentifier }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "VVV"
        let localized = formatter.string(from: Date(timeIntervalSinceReferenceDate: 0))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !localized.isEmpty, localized != "Unknown City" { return localized }
        return timeZoneIdentifier.split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "_",with: " ") ?? timeZoneIdentifier
    }

    /// Returns live search suggestions. Prefix matches come first, followed by
    /// matches found inside the city, country, or IANA time-zone identifier.
    public static func matching(_ entries: [SystemCityEntry],query: String,locale: Locale = .current) -> [SystemCityEntry] {
        let needle = normalized(query,locale: locale)
        guard !needle.isEmpty else { return entries }
        return entries.compactMap { entry -> (SystemCityEntry,Int)? in
            let city = normalized(entry.cityName,locale: locale)
            let country = normalized(entry.countryName,locale: locale)
            let zone = normalized(entry.timeZoneIdentifier.replacingOccurrences(of: "_",with: " "),locale: locale)
            if city.hasPrefix(needle) { return (entry,0) }
            if country.hasPrefix(needle) { return (entry,1) }
            if city.contains(needle) { return (entry,2) }
            if country.contains(needle) || zone.contains(needle) { return (entry,3) }
            return nil
        }.sorted {
            $0.1 == $1.1 ? $0.0.displayName.localizedStandardCompare($1.0.displayName) == .orderedAscending : $0.1 < $1.1
        }.map(\.0)
    }

    private static func normalized(_ value: String,locale: Locale) -> String {
        value.folding(options: [.caseInsensitive,.diacriticInsensitive,.widthInsensitive],locale: locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseISO6709(_ value: String) -> (latitude: Double,longitude: Double)? {
        guard value.count >= 11 else { return nil }
        let signs = value.indices.filter { value[$0] == "+" || value[$0] == "-" }
        guard signs.count == 2, signs[0] == value.startIndex else { return nil }
        return parseCoordinate(String(value[signs[0]..<signs[1]]),degreeDigits: 2).flatMap { latitude in
            parseCoordinate(String(value[signs[1]...]),degreeDigits: 3).map { (latitude,$0) }
        }
    }

    private static func parseCoordinate(_ value: String,degreeDigits: Int) -> Double? {
        guard let sign = value.first, sign == "+" || sign == "-" else { return nil }
        let digits = String(value.dropFirst())
        guard digits.count == degreeDigits+2 || digits.count == degreeDigits+4 else { return nil }
        let degreeEnd = digits.index(digits.startIndex,offsetBy: degreeDigits)
        let minuteEnd = digits.index(degreeEnd,offsetBy: 2)
        guard let degrees = Double(digits[..<degreeEnd]),
              let minutes = Double(digits[degreeEnd..<minuteEnd]),
              let seconds = digits.count == degreeDigits+4 ? Double(digits[minuteEnd...]) : 0,
              minutes < 60, seconds < 60 else { return nil }
        let magnitude = degrees+minutes/60+seconds/3600
        return sign == "-" ? -magnitude : magnitude
    }
}
