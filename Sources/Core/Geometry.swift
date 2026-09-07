import Foundation
import simd

public enum GlobeGeometry {
    public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    public static func position(latitude: Double, longitude: Double) -> SIMD3<Double> {
        let lat = radians(latitude), lon = radians(longitude)
        return SIMD3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
    }
    public static func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }
    /// Orthographic horizon. Both representations crossfade before the anchor is occluded.
    public static func surfaceOpacity(depth: Double) -> Double { smoothstep(0, 0.22, depth) }
}

public struct CameraBasis: Sendable {
    public let right: SIMD3<Double>
    public let up: SIMD3<Double>
    public let front: SIMD3<Double>
    public init(longitude: Double, latitude: Double) {
        let lon = GlobeGeometry.radians(longitude), lat = GlobeGeometry.radians(latitude)
        right = SIMD3(cos(lon), 0, -sin(lon))
        front = GlobeGeometry.position(latitude: latitude, longitude: longitude)
        up = SIMD3(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
    }
    public func project(_ point: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(simd_dot(point, right), simd_dot(point, up), simd_dot(point, front))
    }
    /// Maps a geographic unit vector to the exact orthographic point used by the globe shader.
    /// The z component remains the signed depth, so callers can distinguish the rear hemisphere.
    public func screenProjection(_ point: SIMD3<Double>, earthCenter: SIMD2<Double>, earthRadius: Double) -> SIMD3<Double> {
        let projected = project(point)
        return SIMD3(
            earthCenter.x + projected.x * earthRadius,
            earthCenter.y + projected.y * earthRadius,
            projected.z
        )
    }
}
