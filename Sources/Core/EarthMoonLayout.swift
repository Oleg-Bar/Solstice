import Foundation
import simd

/// Orthographic projection in Earth-radius units. One scale applies to both bodies and their separation.
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
        var radius = min(width,height)*c.earthDiameter/2
        var offset = SIMD2(projected.x,projected.y)
        if c.moonEnabled && lunar.altitudeDegrees > -2 {
            if c.physicalMoonScale {
                let margin = min(width,height)*0.04
                let availableX = projected.x >= 0 ? width-center.x-margin : center.x-margin
                let availableY = projected.y >= 0 ? height-center.y-margin : center.y-margin
                let fitted = min(radius,availableX/(abs(projected.x)+radiusRatio),availableY/(abs(projected.y)+radiusRatio))
                radius += (fitted-radius)*GlobeGeometry.smoothstep(-2,0,lunar.altitudeDegrees)
            } else {
                // Explicit compressed-distance overview; radial direction and orbital variation remain.
                let length = simd_length(offset)
                let direction = length > 1e-6 ? offset/length : SIMD2(1,0)
                offset = direction*(1.65*lunar.distanceKilometers/384400)
            }
        }
        return EarthMoonLayout(earthRadius: radius,moonCenter: center+offset*radius,
            moonRadius: radius*radiusRatio,moonOpacity: opacity,moonDepth: projected.z)
    }
}
