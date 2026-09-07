// Runs the same test methods without requiring Xcode's XCTest framework.
import Foundation

class XCTestCase {}
private var failures = 0
private var assertions = 0
private func record(_ ok: Bool,_ message: String,_ file: StaticString,_ line: UInt) {
    assertions += 1
    if !ok { failures += 1; fputs("FAIL \(file):\(line): \(message)\n",stderr) }
}
func XCTAssertEqual<T: Equatable>(_ a: T,_ b: T,file: StaticString = #filePath,line: UInt = #line) { record(a == b,"\(a) != \(b)",file,line) }
func XCTAssertEqual(_ a: Double,_ b: Double,accuracy: Double,file: StaticString = #filePath,line: UInt = #line) { record(abs(a-b) <= accuracy,"\(a) != \(b) ± \(accuracy)",file,line) }
func XCTAssertTrue(_ a: Bool,file: StaticString = #filePath,line: UInt = #line) { record(a,"Expected true",file,line) }
func XCTAssertLessThan(_ a: Double,_ b: Double,file: StaticString = #filePath,line: UInt = #line) { record(a < b,"\(a) >= \(b)",file,line) }
func XCTAssertGreaterThanOrEqual(_ a: Double,_ b: Double,file: StaticString = #filePath,line: UInt = #line) { record(a >= b,"\(a) < \(b)",file,line) }

@main enum TestRunner {
    static func main() {
        let t = TerraCoreTests()
        let tests: [(String,() -> Void)] = [
            ("geographic axes",t.testGeographicAxesAndSeam),
            ("camera and visibility",t.testCameraProjectionAndVisibility),
            ("horizon continuity",t.testHorizonTransitionIsContinuousAndComplementary),
            ("Madrid DST",t.testMadridDSTSpringGapAndAutumnRepeat),
            ("New York DST / Singapore rollover",t.testNewYorkDSTAndSingaporeDayRollover),
            ("Sun / camera invariance",t.testSunSolsticesEquinoxAndEarthFixedDirection),
            ("leap day / longitude",t.testLeapDayAndLongitudeNormalization),
            ("debug time isolation",t.testDebugTimelineContinuityAndProductionIsolation),
            ("mean lunar phase",t.testMeanLunarPhases),
            ("lunar ephemeris / observer",t.testLunarEphemerisAndObserver),
            ("physical body scale / readable distance / horizon",t.testReadablePhysicalBodyScaleAndHorizon),
            ("IP response validation",t.testIPResponseValidation),
            ("dynamic observer clock",t.testDynamicObserverClock),
            ("macOS system city catalog",t.testSystemCityCatalog),
            ("localized city names / custom removal",t.testSystemCityLocalizationAndCustomRemoval)
        ]
        for (name,test) in tests { let before = failures; test(); print("\(failures == before ? "PASS" : "FAIL") \(name)") }
        print("\(tests.count) tests; \(assertions) assertions; \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
