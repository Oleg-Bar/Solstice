import Foundation
import simd
#if !DIRECT_TESTS
import XCTest
#if SWIFT_PACKAGE
@testable import TerraCore
#endif
#endif

final class TerraCoreTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testGeographicAxesAndSeam() {
        XCTAssertEqual(GlobeGeometry.position(latitude: 0,longitude: 0),SIMD3(0,0,1))
        XCTAssertEqual(GlobeGeometry.position(latitude: 90,longitude: 20).y,1,accuracy: 1e-12)
        XCTAssertEqual(GlobeGeometry.position(latitude: 0,longitude: 90).x,1,accuracy: 1e-12)
        XCTAssertLessThan(simd_length(GlobeGeometry.position(latitude: 12,longitude: 180)-GlobeGeometry.position(latitude: 12,longitude: -180)),1e-12)
        for city in CitiesConfiguration.cities { XCTAssertEqual(simd_length(city.position),1,accuracy: 1e-12) }
    }
    func testCameraProjectionAndVisibility() {
        let camera = CameraBasis(longitude: -3.7038,latitude: 40.4168)
        let madrid = camera.project(CitiesConfiguration.cities[0].position)
        XCTAssertEqual(madrid.x,0,accuracy: 1e-12); XCTAssertEqual(madrid.y,0,accuracy: 1e-12)
        XCTAssertEqual(madrid.z,1,accuracy: 1e-12)
        XCTAssertEqual(camera.project(-CitiesConfiguration.cities[0].position).z,-1,accuracy: 1e-12)
        XCTAssertEqual(simd_dot(camera.up,camera.front),0,accuracy: 1e-12)
        XCTAssertEqual(simd_dot(camera.right,camera.up),0,accuracy: 1e-12)
    }
    func testHorizonTransitionIsContinuousAndComplementary() {
        XCTAssertEqual(GlobeGeometry.surfaceOpacity(depth: -0.2),0)
        XCTAssertEqual(GlobeGeometry.surfaceOpacity(depth: 0),0)
        XCTAssertEqual(GlobeGeometry.surfaceOpacity(depth: 0.22),1)
        XCTAssertEqual(GlobeGeometry.surfaceOpacity(depth: 0.11),0.5,accuracy: 1e-12)
        var previous = 0.0
        for step in 0...1000 {
            let opacity = GlobeGeometry.surfaceOpacity(depth: Double(step)/1000*0.22)
            XCTAssertGreaterThanOrEqual(opacity,previous)
            XCTAssertLessThan(opacity-previous,0.002)
            XCTAssertEqual(opacity+(1-opacity),1)
            previous = opacity
        }
    }
    func testMadridDSTSpringGapAndAutumnRepeat() {
        let city = CitiesConfiguration.cities[0]
        XCTAssertEqual(CityClockState(city: city,date: date("2026-03-29T00:59:00Z")).label,"01:59 AM")
        XCTAssertEqual(CityClockState(city: city,date: date("2026-03-29T01:00:00Z")).label,"03:00 AM")
        XCTAssertEqual(CityClockState(city: city,date: date("2026-10-25T00:30:00Z")).label,"02:30 AM")
        XCTAssertEqual(CityClockState(city: city,date: date("2026-10-25T01:30:00Z")).label,"02:30 AM")
    }
    func testNewYorkDSTAndSingaporeDayRollover() {
        let ny = CitiesConfiguration.cities[2], sg = CitiesConfiguration.cities[1]
        XCTAssertEqual(CityClockState(city: ny,date: date("2026-03-08T06:59:00Z")).hour,1)
        XCTAssertEqual(CityClockState(city: ny,date: date("2026-03-08T07:00:00Z")).hour,3)
        let time = CityClockState(city: sg,date: date("2026-09-05T16:00:00Z"))
        XCTAssertEqual(time.label,"12:00 AM"); XCTAssertEqual(time.day,6)
    }
    func testSunSolsticesEquinoxAndEarthFixedDirection() {
        let summer = SolarPositionCalculator.position(at: date("2026-06-21T12:00:00Z"))
        let winter = SolarPositionCalculator.position(at: date("2026-12-21T12:00:00Z"))
        let equinox = SolarPositionCalculator.position(at: date("2026-03-20T12:00:00Z"))
        XCTAssertEqual(summer.latitude,23.44,accuracy: 0.5)
        XCTAssertEqual(winter.latitude,-23.44,accuracy: 0.5)
        XCTAssertEqual(equinox.latitude,0,accuracy: 1.0)
        XCTAssertEqual(summer.longitude,0,accuracy: 1)
        let evening = SolarPositionCalculator.position(at: date("2026-06-21T18:00:00Z"))
        XCTAssertEqual(evening.longitude,-90,accuracy: 1)
        XCTAssertEqual(simd_length(evening.direction),1,accuracy: 1e-12)
        // Camera rotation must not change whether Madrid is illuminated.
        let normal = CitiesConfiguration.cities[0].position
        for longitude in stride(from: -180.0,through: 180.0,by: 30) {
            let basis = CameraBasis(longitude: longitude,latitude: 15)
            XCTAssertEqual(simd_dot(basis.project(normal),basis.project(summer.direction)),simd_dot(normal,summer.direction),accuracy: 1e-12)
        }
    }
    func testLeapDayAndLongitudeNormalization() {
        for text in ["2024-02-29T00:00:00Z","2024-12-31T23:59:59Z","2025-01-01T00:00:00Z"] {
            let p = SolarPositionCalculator.position(at: date(text))
            XCTAssertTrue(p.latitude.isFinite); XCTAssertTrue((-180...180).contains(p.longitude))
        }
        XCTAssertEqual(SolarPositionCalculator.normalizedLongitude(-541),179)
        XCTAssertEqual(SolarPositionCalculator.normalizedLongitude(541),-179)
    }
    func testDebugTimelineContinuityAndProductionIsolation() {
        let start = date("2026-09-05T12:00:00Z")
        var preview = SceneTimeline(isPreview: true,date: start,uptime: 10)
        preview.setRate(100,uptime: 20)
        XCTAssertEqual(preview.date(uptime: 20),start.addingTimeInterval(10))
        XCTAssertEqual(preview.date(uptime: 21),start.addingTimeInterval(110))
        var saver = SceneTimeline(isPreview: false,date: start,uptime: 10)
        saver.setRate(1000,uptime: 20)
        let now = start.addingTimeInterval(1234)
        XCTAssertEqual(saver.date(now: now,uptime: 21),now)
        XCTAssertEqual(saver.rate,1)
    }
    func testMeanLunarPhases() {
        let reference = Date(timeIntervalSince1970: 947182440)
        XCTAssertEqual(LunarPhaseCalculator.illumination(at: reference),0,accuracy: 1e-12)
        XCTAssertEqual(LunarPhaseCalculator.illumination(at: reference.addingTimeInterval(29.530588853*86400/2)),1,accuracy: 1e-12)
    }
    func testLunarEphemerisAndObserver() {
        // Independent primary reference: USNO lunar phases, September 2026 (UTC).
        for (stamp,fraction) in [("2026-09-11T03:27:00Z",0.0),("2026-09-18T20:44:00Z",0.5),("2026-09-26T16:49:00Z",1.0)] {
            let a = LunarAppearanceCalculator.appearance(at: date(stamp),observer: .madrid)
            XCTAssertEqual(a.illuminatedFraction,fraction,accuracy: 0.015)
            XCTAssertEqual(simd_length(a.lightDirection),1,accuracy: 1e-10)
            XCTAssertTrue((350000...410000).contains(a.distanceKilometers))
            XCTAssertEqual(simd_length(a.earthFixedPosition)*6371,a.distanceKilometers,accuracy: 0.0001)
        }
        let instant = date("2026-09-06T06:00:00Z")
        let a = LunarAppearanceCalculator.appearance(at: instant,observer: .madrid)
        let b = LunarAppearanceCalculator.appearance(at: instant,observer: .singapore)
        XCTAssertEqual(a.distanceKilometers,b.distanceKilometers,accuracy: 1e-6)
        XCTAssertTrue(abs(a.altitudeDegrees-b.altitudeDegrees)>10)
        XCTAssertTrue(simd_length(a.lightDirection-b.lightDirection)>0.1)
    }
    func testPhysicalLayoutAndHorizon() {
        for place in [ObserverLocation.madrid,.singapore] {
            let camera = CameraBasis(longitude: place.longitude,latitude: place.latitude)
            var above = 0, below = 0
            for hour in 0..<24 {
                let moon = LunarAppearanceCalculator.appearance(at: date(String(format:"2026-09-06T%02d:00:00Z",hour)),observer: place)
                var c = SceneConfiguration(); c.physicalMoonScale = true
                let layout = EarthMoonLayout.calculate(width: 1440,height: 900,basis: camera,lunar: moon,configuration: c)
                XCTAssertEqual(layout.moonRadius/layout.earthRadius,1737.4/6371,accuracy: 1e-10)
                if moon.altitudeDegrees <= 0 {
                    below += 1; XCTAssertEqual(layout.moonOpacity,0)
                } else {
                    above += 1
                    let projected = camera.project(moon.earthFixedPosition)
                    XCTAssertEqual((layout.moonCenter.x-720)/layout.earthRadius,projected.x,accuracy: 1e-9)
                    XCTAssertEqual((layout.moonCenter.y-387)/layout.earthRadius,projected.y,accuracy: 1e-9)
                    XCTAssertTrue(layout.moonCenter.x-layout.moonRadius>=0)
                    XCTAssertTrue(layout.moonCenter.x+layout.moonRadius<=1440)
                    XCTAssertTrue(layout.moonCenter.y-layout.moonRadius>=0)
                    XCTAssertTrue(layout.moonCenter.y+layout.moonRadius<=900)
                }
            }
            XCTAssertTrue(above>0 && below>0)
        }
    }
    func testIPResponseValidation() {
        let good = #"{"success":true,"city":"Singapore","latitude":1.35,"longitude":103.8,"timezone":{"id":"Asia/Singapore"}}"#
        do { let place = try LocationResponseParser.parse(Data(good.utf8)); XCTAssertEqual(place.name,"Singapore"); XCTAssertTrue(place.isValid) }
        catch { XCTAssertTrue(false) }
        for bad in [#"{"success":false}"#,#"{"success":true,"latitude":100,"longitude":0,"timezone":{"id":"Europe/Madrid"}}"#,#"{"success":true}"#] {
            do { _ = try LocationResponseParser.parse(Data(bad.utf8)); XCTAssertTrue(false) }
            catch { XCTAssertTrue(true) }
        }
    }

    func testDynamicObserverClock() {
        XCTAssertEqual(CitiesConfiguration.including(observer: .madrid).count,3)
        let tokyo = ObserverLocation(name: "Tokyo",latitude: 35.6762,longitude: 139.6503,timeZoneIdentifier: "Asia/Tokyo")
        let cities = CitiesConfiguration.including(observer: tokyo)
        XCTAssertEqual(cities.count,4); XCTAssertEqual(cities[0].name,"Tokyo")
        let clock = CityClockState(city: cities[0],date: date("2026-09-06T00:00:00Z"))
        XCTAssertEqual(clock.hour,9)
        let p = CameraBasis(longitude: tokyo.longitude,latitude: tokyo.latitude).project(cities[0].position)
        XCTAssertEqual(p.z,1,accuracy: 1e-10)
        XCTAssertEqual(CitiesConfiguration.including(observer: .singapore)[0].name,"Singapore")
    }

}
