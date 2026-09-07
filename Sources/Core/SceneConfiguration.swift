import Foundation

public struct SceneConfiguration: Sendable {
    public var earthDiameter = 0.70 // fraction of the smaller viewport dimension
    public var earthVerticalPosition = 0.43 // from bottom
    public var rotationDegreesPerSecond = 0.0 // location-focused view; optional orbit in preview
    public var initialLongitude = -3.7038
    public var cameraLatitude = 40.4168
    public var automaticIPLocation = false // enabled only after explicit consent to contact ipwho.is
    public var moonEnabled = true
    public var starBrightness = 0.055
    public var milkyWayBrightness = 0.27 // slightly brighter, still subordinate to Earth
    public var atmosphereIntensity = 0.58
    public var nightLightsIntensity = 2.2
    public var clockScale = 1.01 // all city clocks share one radius, increased by 1%
    public var cityLabelScale = 1.0
    public var preferredFramesPerSecond = 1 // maximum battery saving; clocks and astronomy remain current each second
    public var maximumDrawableDimension = 5120.0 // native 5K output; smaller displays keep their native drawable size
    public init() {}
}

/// Preview alone can change time rate. Production asks Date() for each frame.
public struct SceneTimeline {
    public let isPreview: Bool
    private var anchorDate: Date
    private var anchorUptime: TimeInterval
    public private(set) var rate: Double = 1
    public init(isPreview: Bool, date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.isPreview = isPreview; anchorDate = date; anchorUptime = uptime
    }
    public func date(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Date {
        isPreview ? anchorDate.addingTimeInterval((uptime - anchorUptime) * rate) : now
    }
    public mutating func setRate(_ value: Double, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard isPreview else { return }
        anchorDate = date(uptime: uptime); anchorUptime = uptime; rate = value
    }
    public mutating func reset(date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        anchorDate = date; anchorUptime = uptime; rate = 1
    }
}
