import Foundation
import simd
import TerraAstronomy

public struct LunarAppearance: Sendable {
    public let distanceKilometers: Double
    public let observerDistanceKilometers: Double
    public let earthFixedPosition: SIMD3<Double>
    public let lightDirection: SIMD3<Double>
    public let northPositionAngle: Double
    public let librationLongitude: Double
    public let librationLatitude: Double
    public let illuminatedFraction: Double
    public let altitudeDegrees: Double
    public let azimuthDegrees: Double
}

public enum LunarAppearanceCalculator {
    private static func vector(_ value: astro_vector_t) -> SIMD3<Double> { SIMD3(value.x,value.y,value.z) }
    public static func appearance(at date: Date, observer: ObserverLocation) -> LunarAppearance {
        precondition(observer.isValid)
        var time = Astronomy_TimeFromDays((date.timeIntervalSince1970-946728000)/86400)
        let place = Astronomy_MakeObserver(observer.latitude,observer.longitude,0)
        let earthToObserver = vector(Astronomy_ObserverVector(&time,place,EQUATOR_J2000))
        let earthToMoon = vector(Astronomy_GeoVector(BODY_MOON,time,NO_ABERRATION))
        let earthToSun = vector(Astronomy_GeoVector(BODY_SUN,time,NO_ABERRATION))
        let moonDate = vector(Astronomy_RotateVector(Astronomy_Rotation_EQJ_EQD(&time),
            Astronomy_GeoVector(BODY_MOON,time,NO_ABERRATION)))
        let longitude = atan2(moonDate.y,moonDate.x)*180 / .pi-Astronomy_SiderealTime(&time)*15
        let latitude = atan2(moonDate.z,hypot(moonDate.x,moonDate.y))*180 / .pi
        let distance = simd_length(earthToMoon)*149597870.7
        let earthFixed = GlobeGeometry.position(latitude: latitude,longitude: longitude)*(distance/6371)
        let towardMoon = simd_normalize(earthToMoon-earthToObserver)
        // Geodetic zenith, transformed from equator-of-date to the J2000 frame.
        let zenithDate = Astronomy_VectorFromSphere(astro_spherical_t(status: ASTRO_SUCCESS,lat: observer.latitude,
            lon: Astronomy_SiderealTime(&time)*15+observer.longitude,dist: 1),time)
        let zenith = vector(Astronomy_RotateVector(Astronomy_Rotation_EQD_EQJ(&time),zenithDate))
        var right = simd_cross(towardMoon,zenith)
        if simd_length(right) < 1e-8 { right = simd_cross(towardMoon,SIMD3(0,0,1)) }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right,towardMoon))
        let front = -towardMoon
        let sunlight = simd_normalize(earthToSun-earthToMoon)
        let localLight = SIMD3(simd_dot(sunlight,right),simd_dot(sunlight,up),simd_dot(sunlight,front))
        let pole = vector(Astronomy_RotationAxis(BODY_MOON,&time).north)
        let northAngle = atan2(simd_dot(pole,right),simd_dot(pole,up))
        let equator = Astronomy_Equator(BODY_MOON,&time,place,EQUATOR_OF_DATE,NO_ABERRATION)
        let horizon = Astronomy_Horizon(&time,place,equator.ra,equator.dec,REFRACTION_NONE)
        let libration = Astronomy_Libration(time)
        return LunarAppearance(distanceKilometers: distance,
            observerDistanceKilometers: simd_length(earthToMoon-earthToObserver)*149597870.7,
            earthFixedPosition: earthFixed,lightDirection: localLight,northPositionAngle: northAngle,
            librationLongitude: libration.elon,librationLatitude: libration.elat,
            illuminatedFraction: (1+localLight.z)/2,altitudeDegrees: horizon.altitude,azimuthDegrees: horizon.azimuth)
    }
}
