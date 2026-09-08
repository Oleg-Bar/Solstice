import Foundation

public struct ObserverLocation: Codable, Equatable, Sendable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public static let madrid = ObserverLocation(name: "Madrid",latitude: 40.4168,longitude: -3.7038,timeZoneIdentifier: "Europe/Madrid")
    public static let newYork = ObserverLocation(name: "New York",latitude: 40.7128,longitude: -74.0060,timeZoneIdentifier: "America/New_York")
    public static let singapore = ObserverLocation(name: "Singapore",latitude: 1.3521,longitude: 103.8198,timeZoneIdentifier: "Asia/Singapore")
    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.name = name; self.latitude = latitude; self.longitude = longitude; self.timeZoneIdentifier = timeZoneIdentifier
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude)
            && (-180...180).contains(longitude) && TimeZone(identifier: timeZoneIdentifier) != nil
    }
}

public enum IPLocationConsentStore {
    private static let key = "ipLocationConsent"
    private static var defaults: UserDefaults { UserDefaults(suiteName: "studio.terra.shared") ?? .standard }
    public static var decision: Bool? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }
    public static func setAllowed(_ allowed: Bool) { defaults.set(allowed,forKey: key) }
}

public enum LocationResponseParser {
    private struct Response: Decodable {
        struct Zone: Decodable { let id: String }
        let success: Bool
        let city: String?
        let country: String?
        let latitude: Double?
        let longitude: Double?
        let timezone: Zone?
    }
    public static func parse(_ data: Data) throws -> ObserverLocation {
        let response = try JSONDecoder().decode(Response.self,from: data)
        guard response.success, let lat = response.latitude, let lon = response.longitude,
              let zone = response.timezone?.id else { throw LocationError.invalidResponse }
        let city = response.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = ObserverLocation(name: city.isEmpty ? (response.country ?? "Моё местоположение") : city,
            latitude: lat,longitude: lon,timeZoneIdentifier: zone)
        guard location.isValid else { throw LocationError.invalidResponse }
        return location
    }
    public enum LocationError: Error { case invalidResponse }
}

/// One lookup shared by every display in a host process. No location is written to disk.
public actor IPLocationResolver {
    public static let shared = IPLocationResolver()
    public nonisolated static let refreshInterval: TimeInterval = 12 * 60 * 60
    private var cached: (Date,ObserverLocation)?
    private var inFlight: Task<ObserverLocation,Error>?
    public func resolve(force: Bool = false) async throws -> ObserverLocation {
        if !force, let (date,location) = cached,
           Date().timeIntervalSince(date) < Self.refreshInterval { return location }
        if let task = inFlight { return try await task.value }
        let task = Task<ObserverLocation,Error> {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 10
            configuration.httpCookieStorage = nil
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let url = URL(string: "https://ipwho.is/?fields=success,city,country,latitude,longitude,timezone.id")!
            let (data,response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw LocationResponseParser.LocationError.invalidResponse }
            return try LocationResponseParser.parse(data)
        }
        inFlight = task
        do {
            let result = try await task.value
            cached = (Date(),result); inFlight = nil
            return result
        } catch { inFlight = nil; throw error }
    }
}
