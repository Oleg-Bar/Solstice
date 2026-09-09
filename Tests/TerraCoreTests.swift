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
        let screenCenter = SIMD2(720.0,387.0)
        let madridScreen = camera.screenProjection(CitiesConfiguration.cities[0].position,earthCenter: screenCenter,earthRadius: 315)
        XCTAssertEqual(madridScreen.x,screenCenter.x,accuracy: 1e-10)
        XCTAssertEqual(madridScreen.y,screenCenter.y,accuracy: 1e-10)
        XCTAssertEqual(madridScreen.z,1,accuracy: 1e-12)
        let singapore = CitiesConfiguration.cities[1]
        let projected = camera.project(singapore.position)
        let singaporeScreen = camera.screenProjection(singapore.position,earthCenter: screenCenter,earthRadius: 315)
        XCTAssertEqual(singaporeScreen.x,screenCenter.x+projected.x*315,accuracy: 1e-10)
        XCTAssertEqual(singaporeScreen.y,screenCenter.y+projected.y*315,accuracy: 1e-10)
        XCTAssertEqual(singaporeScreen.z,projected.z,accuracy: 1e-12)
        let equatorialCamera = CameraBasis(longitude: 0,latitude: 0)
        let eastEdge = equatorialCamera.screenProjection(
            GlobeGeometry.position(latitude: 0,longitude: 90),earthCenter: screenCenter,earthRadius: 315)
        XCTAssertEqual(eastEdge.x,screenCenter.x+315,accuracy: 1e-10)
        XCTAssertEqual(eastEdge.y,screenCenter.y,accuracy: 1e-10)
        XCTAssertEqual(eastEdge.z,0,accuracy: 1e-10)
        let northEdge = equatorialCamera.screenProjection(
            GlobeGeometry.position(latitude: 90,longitude: 0),earthCenter: screenCenter,earthRadius: 315)
        XCTAssertEqual(northEdge.x,screenCenter.x,accuracy: 1e-10)
        XCTAssertEqual(northEdge.y,screenCenter.y+315,accuracy: 1e-10)
        XCTAssertEqual(northEdge.z,0,accuracy: 1e-10)
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
        let madrid = CitiesConfiguration.cities[0]
        XCTAssertTrue(CityClockState(city: madrid,date: date("2026-06-21T12:00:00Z")).isDaylight)
        XCTAssertTrue(!CityClockState(city: madrid,date: date("2026-06-21T00:00:00Z")).isDaylight)
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

        // NASA/JPL Horizons DE441, topocentric observer at Madrid,
        // 2026-09-07 12:00 UTC: azimuth, airless elevation, illuminated disc and range.
        let jpl = LunarAppearanceCalculator.appearance(at: date("2026-09-07T12:00:00Z"),observer: .madrid)
        XCTAssertEqual(jpl.azimuthDegrees,258.269192,accuracy: 0.08)
        XCTAssertEqual(jpl.altitudeDegrees,49.578733,accuracy: 0.08)
        XCTAssertEqual(jpl.illuminatedFraction,0.1677126,accuracy: 0.0015)
        XCTAssertEqual(jpl.observerDistanceKilometers,0.00243001818327*149597870.7,accuracy: 80)
    }
    func testReadablePhysicalBodyScaleAndHorizon() {
        for place in [ObserverLocation.madrid,.singapore] {
            let camera = CameraBasis(longitude: place.longitude,latitude: place.latitude)
            var above = 0, below = 0
            for hour in 0..<24 {
                let moon = LunarAppearanceCalculator.appearance(at: date(String(format:"2026-09-06T%02d:00:00Z",hour)),observer: place)
                let c = SceneConfiguration()
                let layout = EarthMoonLayout.calculate(width: 1440,height: 900,basis: camera,lunar: moon,configuration: c)
                XCTAssertEqual(layout.moonRadius/layout.earthRadius,1737.4/6371,accuracy: 1e-10)
                XCTAssertEqual(layout.earthRadius,315,accuracy: 1e-10)
                if moon.altitudeDegrees <= 0 {
                    below += 1; XCTAssertEqual(layout.moonOpacity,0)
                } else {
                    above += 1
                    let separation = simd_length(layout.moonCenter-SIMD2(720,387))/layout.earthRadius
                    XCTAssertEqual(separation,1.65*moon.distanceKilometers/384400,accuracy: 1e-9)
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
        let configuration = SceneConfiguration()
        XCTAssertTrue(!configuration.automaticIPLocation)
        XCTAssertEqual(configuration.maximumDrawableDimension,5120)
        XCTAssertEqual(configuration.preferredFramesPerSecond,1)
        XCTAssertEqual(IPLocationResolver.refreshInterval,12*60*60)
        XCTAssertEqual(configuration.milkyWayBrightness,0.35,accuracy: 1e-12)
        XCTAssertEqual(configuration.clockScale,1.01,accuracy: 1e-12)
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
        XCTAssertEqual(cities.count,4); XCTAssertEqual(cities[0].timeZoneIdentifier,"Asia/Tokyo")
        let lisbon = City(name: "Lisbon",latitude: 38.7223,longitude: -9.1393,timeZoneIdentifier: "Europe/Lisbon")
        let extended = CitiesConfiguration.including(observer: .madrid,additional: [lisbon])
        XCTAssertEqual(extended.count,4); XCTAssertTrue(extended.contains(where: { $0.name == "Lisbon" }))
        let clock = CityClockState(city: cities[0],date: date("2026-09-06T00:00:00Z"))
        XCTAssertEqual(clock.hour,9)
        let p = CameraBasis(longitude: tokyo.longitude,latitude: tokyo.latitude).project(cities[0].position)
        XCTAssertEqual(p.z,1,accuracy: 1e-10)
        XCTAssertEqual(CitiesConfiguration.including(observer: .singapore)[0].timeZoneIdentifier,"Asia/Singapore")
    }

    func testSystemCityCatalog() {
        let sample = """
        # system tzdb sample
        ES\t+4024-00341\tEurope/Madrid\tSpain (mainland)
        JP\t+353916+1394441\tAsia/Tokyo
        US\t+404251-0740023\tAmerica/New_York\tEastern (most areas)
        """
        let entries = SystemCityCatalog.parse(sample,locale: Locale(identifier: "en_US"))
        XCTAssertEqual(entries.count,3)
        let madrid = entries.first { $0.timeZoneIdentifier == "Europe/Madrid" }!
        XCTAssertEqual(madrid.cityName,"Madrid")
        XCTAssertEqual(madrid.countryName,"Spain")
        XCTAssertEqual(madrid.latitude,40.4,accuracy: 1e-10)
        XCTAssertEqual(madrid.longitude,-3.6833333333,accuracy: 1e-9)
        let tokyo = entries.first { $0.timeZoneIdentifier == "Asia/Tokyo" }!
        XCTAssertEqual(tokyo.latitude,35.6544444444,accuracy: 1e-9)
        XCTAssertEqual(tokyo.longitude,139.7447222222,accuracy: 1e-9)
        let system = SystemCityCatalog.load(locale: Locale(identifier: "en_US"))
        XCTAssertTrue(system.count > 300)
        XCTAssertTrue(system.contains { $0.timeZoneIdentifier == "America/New_York" })
    }

    func testSystemCityLocalizationAndCustomRemoval() {
        XCTAssertEqual(SystemCityCatalog.localizedCityName(for: "Europe/Madrid",locale: Locale(identifier: "en_US")),"Madrid")
        XCTAssertEqual(SystemCityCatalog.localizedCityName(for: "Europe/Madrid",locale: Locale(identifier: "es_ES")),"Madrid")
        XCTAssertEqual(SystemCityCatalog.localizedCityName(for: "Europe/Madrid",locale: Locale(identifier: "ru_RU")),"Мадрид")
        XCTAssertEqual(SystemCityCatalog.localizedCityName(for: "Europe/Madrid",locale: Locale(identifier: "zh_CN")),"马德里")
        let london = City(name: "London",latitude: 51.5074,longitude: -0.1278,timeZoneIdentifier: "Europe/London")
        let tokyo = City(name: "Tokyo",latitude: 35.6762,longitude: 139.6503,timeZoneIdentifier: "Asia/Tokyo")
        let updated = CityStore.removing(id: london.id,from: [london,tokyo])
        XCTAssertEqual(updated?.count,1)
        XCTAssertEqual(updated?.first?.id,tokyo.id)
        XCTAssertTrue(CityStore.removing(id: "missing",from: [london,tokyo]) == nil)
        let russian = SystemCityCatalog.parse("ES\t+4024-00341\tEurope/Madrid\nGB\t+513030-0000731\tEurope/London",
            locale: Locale(identifier: "ru_RU"))
        XCTAssertEqual(SystemCityCatalog.matching(russian,query: "мад").first?.timeZoneIdentifier,"Europe/Madrid")
        XCTAssertEqual(SystemCityCatalog.matching(russian,query: "дри").first?.timeZoneIdentifier,"Europe/Madrid")
        XCTAssertTrue(SystemCityCatalog.matching(russian,query: "токио").isEmpty)
        XCTAssertTrue(CitiesConfiguration.matchesObserver(CitiesConfiguration.cities[0],observer: .madrid))
        let withoutMadrid = CitiesConfiguration.cities.filter { $0.timeZoneIdentifier != "Europe/Madrid" }
        XCTAssertTrue(!CitiesConfiguration.including(observer: tokyoObserver,selection: withoutMadrid)
            .contains { $0.timeZoneIdentifier == "Europe/Madrid" })
    }

    private var tokyoObserver: ObserverLocation {
        ObserverLocation(name: "Tokyo",latitude: 35.6762,longitude: 139.6503,timeZoneIdentifier: "Asia/Tokyo")
    }

    func testRetinaLayoutAcrossMacDisplays() {
        let configuration = SceneConfiguration()
        let lunar = LunarAppearanceCalculator.appearance(
            at: ISO8601DateFormatter().date(from: "2026-09-08T08:00:00Z")!,observer: .madrid)
        let basis = CameraBasis(longitude: configuration.initialLongitude,latitude: configuration.cameraLatitude)
        // Native Retina pixels and their exact 2x AppKit point viewports.
        let displays: [(String,Double,Double)] = [
            ("MacBook 13-inch M1",2560,1600),
            ("MacBook Pro 14-inch",3024,1964),
            ("MacBook Pro 16-inch",3456,2234),
            ("4K Retina monitor",3840,2160),
            ("iMac 4.5K",4480,2520),
            ("5K Retina monitor",5120,2880)
        ]
        var baselineClockRadius = 0.0
        for (index,display) in displays.enumerated() {
            let width = display.1/2, height = display.2/2
            let layout = EarthMoonLayout.calculate(width: width,height: height,basis: basis,lunar: lunar,configuration: configuration)
            let clockRadius = SceneLayoutMetrics.clockRadius(width: width,height: height,configuration: configuration)
            if index == 0 { baselineClockRadius = clockRadius }
            XCTAssertEqual(layout.moonRadius/layout.earthRadius,EarthMoonLayout.radiusRatio,accuracy: 1e-12)
            XCTAssertEqual(layout.earthRadius,min(width,height)*configuration.earthDiameter/2,accuracy: 1e-12)
            XCTAssertTrue(clockRadius >= baselineClockRadius)
            XCTAssertTrue(clockRadius*4 >= 140) // diameter at 2x Retina backing scale
            XCTAssertTrue(layout.moonCenter.x+layout.moonRadius <= width)
            XCTAssertTrue(layout.moonCenter.y-layout.moonRadius >= 0)
            XCTAssertTrue(layout.moonCenter.y+layout.moonRadius <= height)
        }
    }

    func testVersionComparison() {
        XCTAssertTrue(AppVersion.isNewer("v1.08",than: "1.07"))
        XCTAssertTrue(AppVersion.isNewer("2.0",than: "1.99"))
        XCTAssertTrue(!AppVersion.isNewer("1.08",than: "1.08"))
        XCTAssertTrue(!AppVersion.isNewer("1.07.9",than: "1.08"))
    }

    /// Every catalogue city on the rear hemisphere keeps its clock disc clear of the lunar
    /// disc, for every camera bearing and every hour the Moon is drawn. The same resolver
    /// the overlay calls is exercised here, so the invariant cannot drift from the drawing.
    func testWorldCityClocksNeverCoverTheLunarDisc() {
        let size = SIMD2(1440.0,900.0)
        var configuration = SceneConfiguration()
        configuration.moonEnabled = true
        let catalog = SystemCityCatalog.load(locale: Locale(identifier: "en_US"))
        XCTAssertGreaterThanOrEqual(Double(catalog.count),300)
        var worstHidden = Double.infinity, worstFront = Double.infinity
        var worstHiddenCity = "", worstFrontCity = "", checked = 0
        for observer in [ObserverLocation.madrid,.singapore,.newYork] {
            for hour in stride(from: 0,through: 22,by: 2) {
                let date = ISO8601DateFormatter().date(from: String(format: "2026-09-09T%02d:00:00Z",hour))!
                let lunar = LunarAppearanceCalculator.appearance(at: date,observer: observer)
                for longitude in stride(from: 0.0,to: 360.0,by: 10.0) {
                    let basis = CameraBasis(longitude: longitude,latitude: observer.latitude)
                    let layout = EarthMoonLayout.calculate(width: size.x,height: size.y,basis: basis,lunar: lunar,configuration: configuration)
                    guard let moon = layout.obstacle else { continue }
                    let earthCenter = SIMD2(size.x*0.5,size.y*configuration.earthVerticalPosition)
                    let earthRadius = layout.earthRadius
                    let clockRadius = SceneLayoutMetrics.clockRadius(
                        width: size.x,height: size.y,configuration: configuration)
                    let envelope = SIMD2(clockRadius*3.7,clockRadius*3.6*configuration.cityLabelScale)
                    let hiddenDistance = earthRadius+clockRadius*3.5+20
                    for entry in catalog {
                        let projected = basis.project(entry.city.position)
                        let opacity = GlobeGeometry.surfaceOpacity(depth: projected.z)
                        let bearing = SIMD2(projected.x,projected.y)
                        let bearingLength = simd_length(bearing)
                        let direction = bearingLength > 0.001 ? bearing/bearingLength : SIMD2(-1,0)
                        if opacity < 0.99 {
                            let center = ClockPlacement.resolve(earthCenter+direction*hiddenDistance,envelope: envelope,
                                radius: clockRadius,moon: moon,
                                limits: (SIMD2(clockRadius*2.5,clockRadius*3.2),SIMD2(size.x-clockRadius*2.5,size.y-clockRadius*2)))
                            let gap = simd_length(center-moon.center)-moon.radius-clockRadius
                            if gap < worstHidden { worstHidden = gap; worstHiddenCity = entry.displayName }
                            checked += 1
                        }
                        if opacity > 0.01 {
                            let center = ClockPlacement.resolve(earthCenter+bearing*earthRadius,envelope: envelope,
                                radius: clockRadius,moon: moon,
                                limits: (SIMD2(clockRadius*2,clockRadius*3),SIMD2(size.x-clockRadius*2,size.y-clockRadius*1.2)))
                            let gap = simd_length(center-moon.center)-moon.radius-clockRadius
                            if gap < worstFront { worstFront = gap; worstFrontCity = entry.displayName }
                            checked += 1
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(Double(checked),10000)
        XCTAssertGreaterThanOrEqual(worstHidden,0)
        XCTAssertGreaterThanOrEqual(worstFront,0)
        XCTAssertEqual(worstHidden >= 0 ? "ok" : worstHiddenCity,"ok")
        XCTAssertEqual(worstFront >= 0 ? "ok" : worstFrontCity,"ok")
    }

}
