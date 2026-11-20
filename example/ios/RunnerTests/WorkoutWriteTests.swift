import CoreLocation
import Flutter
import HealthKit
import XCTest

@testable import health

/// HKWorkout raises an exception (crashing the app) for a time range it does not accept, so the
/// writer checks the range and the units of the totals first. It also turns the locations of
/// workout routes into CLLocations.
class WorkoutWriteTests: XCTestCase {
  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:],
    unitDict: ["KILOCALORIE": .kilocalorie(), "METER": .meter()],
    workoutActivityTypeMap: ["RUNNING": .running]
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)
  private let fourDays: TimeInterval = 4 * 24 * 60 * 60

  func testAcceptsFourDays() {
    XCTAssertNoThrow(try checkDates(lasting: fourDays))
  }

  func testRejectsMoreThanFourDays() {
    XCTAssertEqual(
      pluginErrorMessage(try checkDates(lasting: fourDays + 1)),
      "A HKWorkoutTypeIdentifier sample can last at most 345600 seconds"
    )
  }

  func testRejectsStartAfterEnd() {
    XCTAssertEqual(
      pluginErrorMessage(try checkDates(lasting: -1)),
      "startTime must be equal to or earlier than endTime"
    )
  }

  func testRejectsEndAtDistantFuture() {
    let workoutType = HKObjectType.workoutType()
    XCTAssertEqual(
      pluginErrorMessage(
        try writer.checkSampleDates(start: .distantFuture, end: .distantFuture, of: workoutType)
      ),
      "endTime is too far in the future"
    )
  }

  func testTotalIsOptional() throws {
    XCTAssertNil(try energy([:]))
    let total = try energy(["totalEnergyBurned": 300.0, "totalEnergyBurnedUnit": "KILOCALORIE"])
    XCTAssertEqual(total?.doubleValue(for: .kilocalorie()), 300)
  }

  func testTotalNeedsUnit() {
    XCTAssertEqual(
      pluginErrorMessage(try energy(["totalEnergyBurned": 300.0])),
      "Argument totalEnergyBurnedUnit must name a unit that is available on iOS"
    )
  }

  func testTotalRejectsLengthUnitForEnergy() {
    XCTAssertEqual(
      pluginErrorMessage(try energy(["totalEnergyBurned": 300.0, "totalEnergyBurnedUnit": "METER"])),
      "Unit METER cannot be used for totalEnergyBurned"
    )
  }

  func testTooLongWorkoutRepliesOnce() throws {
    let writes: [String: (FlutterMethodCall, @escaping FlutterResult) throws -> Void] = [
      "writeWorkoutData": writer.writeWorkoutData,
      "writeWorkoutDataUUID": writer.writeWorkoutDataUUID,
    ]
    for (method, write) in writes {
      let sent = try replies(
        to: write, method: method,
        arguments: [
          "activityType": "RUNNING", "startTime": milliseconds(start),
          "endTime": milliseconds(start + 5 * 24 * 60 * 60),
        ]
      )
      XCTAssertEqual(sent.count, 1, method)
      XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT", method)
    }
  }

  /// A CLLocation always has an altitude. A route location written without one gets a negative
  /// vertical accuracy, which marks its altitude invalid, so it does not read back as 0 m.
  func testRouteLocationWithoutAltitudeHasNoValidAltitude() throws {
    let locations = try writer.parseLocations([
      ["latitude": 55.68, "longitude": 12.57, "timestamp": 1_700_000_000_000],
      ["latitude": 55.68, "longitude": 12.57, "timestamp": 1_700_000_001_000, "verticalAccuracy": 5.0],
    ])
    XCTAssertEqual(locations.map(\.verticalAccuracy), [-1, -1])
  }

  func testRouteLocationKeepsItsAltitude() throws {
    let locations = try writer.parseLocations([
      [
        "latitude": 55.68, "longitude": 12.57, "timestamp": 1_700_000_000_000, "altitude": 12.5,
        "verticalAccuracy": 5.0,
      ],
      ["latitude": 55.68, "longitude": 12.57, "timestamp": 1_700_000_001_000, "altitude": 0.0],
    ])
    XCTAssertEqual(locations.map(\.altitude), [12.5, 0])
    XCTAssertEqual(locations.map(\.verticalAccuracy), [5, kCLLocationAccuracyHundredMeters])
  }

  private func checkDates(lasting duration: TimeInterval) throws {
    try writer.checkSampleDates(start: start, end: start + duration, of: HKObjectType.workoutType())
  }

  /// The total energy burned the arguments give, in kilocalories.
  private func energy(_ arguments: NSDictionary) throws -> HKQuantity? {
    try writer.workoutTotal(
      arguments, valueKey: "totalEnergyBurned", unitKey: "totalEnergyBurnedUnit",
      compatibleWith: .kilocalorie()
    )
  }
}
