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
