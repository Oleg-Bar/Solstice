import Foundation
@main enum Check {
 static func main() async {
  if CommandLine.arguments.contains("--ip") {
   do { let place = try await IPLocationResolver.shared.resolve(); print("IP location: \(place.name), \(place.timeZoneIdentifier)") }
   catch { print("IP lookup failed: \(error.localizedDescription)") }
  }
  if CommandLine.arguments.contains("--now") {
   let date = Date()
   let moon = LunarAppearanceCalculator.appearance(at: date,observer: .madrid)
   let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "Europe/Madrid"); formatter.dateFormat = "dd.MM.yyyy HH:mm"
   print(String(format:"Madrid %@: Moon altitude %.2f degrees, azimuth %.2f degrees, illumination %.1f percent",formatter.string(from: date),moon.altitudeDegrees,moon.azimuthDegrees,moon.illuminatedFraction*100))
   return
  }
  for place in [ObserverLocation.madrid,.singapore] {
   for hour in stride(from: 0,through: 21,by: 3) {
    let date = ISO8601DateFormatter().date(from: String(format: "2026-09-06T%02d:00:00Z",hour))!
    let moon = LunarAppearanceCalculator.appearance(at: date,observer: place)
    print(String(format:"%@ %02d UTC altitude %.2f azimuth %.2f distance %.0f km phase %.4f",place.name,hour,moon.altitudeDegrees,moon.azimuthDegrees,moon.distanceKilometers,moon.illuminatedFraction))
   }
  }
 }
}
