import Foundation
import simd

/// Readable overview with physically proportional body sizes.
/// The separation is normalized and placed horizontally so both bodies stay in frame.
public struct EarthMoonLayout {
    public static let radiusRatio = 1737.4/6371.0
    public let earthRadius: Double
    public let moonCenter: SIMD2<Double>
    public let moonRadius: Double
    public let moonOpacity: Double
    public let moonDepth: Double
    public static func calculate(width: Double,height: Double,basis: CameraBasis,
        lunar: LunarAppearance,configuration c: SceneConfiguration) -> EarthMoonLayout {
        let center = SIMD2(width*0.5,height*c.earthVerticalPosition)
        let projected = basis.project(lunar.earthFixedPosition)
        let opacity = c.moonEnabled ? GlobeGeometry.smoothstep(0,0.5,lunar.altitudeDegrees) : 0
        let radius = min(width,height)*c.earthDiameter/2
        let offset = SIMD2(1.65*lunar.distanceKilometers/384400,0)
        return EarthMoonLayout(earthRadius: radius,moonCenter: center+offset*radius,
            moonRadius: radius*radiusRatio,moonOpacity: opacity,moonDepth: projected.z)
    }
}

/// The lunar disc as a layout obstacle, in viewport coordinates.
public struct MoonObstacle: Sendable {
    public let center: SIMD2<Double>
    public let radius: Double
    public init(center: SIMD2<Double>,radius: Double) { self.center = center; self.radius = radius }
}

extension EarthMoonLayout {
    /// The Moon only occupies layout space while it is actually drawn.
    public var obstacle: MoonObstacle? {
        moonOpacity > 0.01 ? MoonObstacle(center: moonCenter,radius: moonRadius) : nil
    }
}

/// Resolves where a city clock may sit relative to the lunar disc.
public enum ClockPlacement {
    public static let moonClearance: Double = 6
    /// Clamps `center` to `limits`, then keeps the clock's reserved envelope — the dial
    /// plus its two label lines — clear of the lunar disc. Clamping first is what makes
    /// the separation survive the on-screen limits. The escape axis is the shortest one
    /// that still fits inside `limits`; when none fits, clearing the Moon wins.
    public static func resolve(_ center: SIMD2<Double>,envelope: SIMD2<Double>,radius: Double,
        moon: MoonObstacle?,limits: (min: SIMD2<Double>,max: SIMD2<Double>)) -> SIMD2<Double> {
        let clamped = SIMD2(min(max(center.x,limits.min.x),limits.max.x),
            min(max(center.y,limits.min.y),limits.max.y))
        guard let moon, moon.radius > 0 else { return clamped }
        let margin = moon.radius+moonClearance
        let minX = clamped.x-envelope.x/2-margin, maxX = clamped.x+envelope.x/2+margin
        let minY = clamped.y-radius*2.5-margin, maxY = clamped.y-radius*2.5+envelope.y+margin
        guard moon.center.x > minX, moon.center.x < maxX, moon.center.y > minY, moon.center.y < maxY else { return clamped }
        let escapes: [(offset: SIMD2<Double>,depth: Double)] = [
            (SIMD2(-(maxX-moon.center.x),0),maxX-moon.center.x),
            (SIMD2(moon.center.x-minX,0),moon.center.x-minX),
            (SIMD2(0,-(maxY-moon.center.y)),maxY-moon.center.y),
            (SIMD2(0,moon.center.y-minY),moon.center.y-minY)
        ]
        func fits(_ point: SIMD2<Double>) -> Bool {
            point.x >= limits.min.x && point.x <= limits.max.x && point.y >= limits.min.y && point.y <= limits.max.y
        }
        let ordered = escapes.sorted { $0.depth < $1.depth }
        return clamped+(ordered.first { fits(clamped+$0.offset) } ?? ordered[0]).offset
    }
}
