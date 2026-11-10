import HealthKit
import XCTest

@testable import health

/// The maps that reads give for samples, as the Dart side parses them.
class SampleConversionTests: XCTestCase {
  private let reader = HealthDataReader(
    healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testWorkoutsHaveTheirFlightsClimbedAndSwimmingStrokes() throws {
    let swim = HKWorkout(
      activityType: .swimming, start: start, end: start + 30 * 60, workoutEvents: nil,
      totalEnergyBurned: nil, totalDistance: HKQuantity(unit: .meter(), doubleValue: 1000),
      totalSwimmingStrokeCount: HKQuantity(unit: .count(), doubleValue: 640), device: nil, metadata: nil
    )
    let climb = HKWorkout(
      activityType: .stairClimbing, start: start, end: start + 30 * 60, workoutEvents: nil,
      totalEnergyBurned: nil, totalDistance: nil,
      totalFlightsClimbed: HKQuantity(unit: .count(), doubleValue: 12), device: nil, metadata: nil
    )
    let maps = try self.maps(of: [swim, climb], type: HealthConstants.WORKOUT)
    XCTAssertEqual(maps[0]["totalSwimmingStrokeCount"] as? Double, 640)
    XCTAssertEqual(maps[1]["totalFlightsClimbed"] as? Double, 12)
    // A total the workout does not have is null on the Dart side.
    XCTAssertTrue(maps[0]["totalFlightsClimbed"] is NSNull)
    XCTAssertTrue(maps[1]["totalSwimmingStrokeCount"] is NSNull)
  }

  /// The maps that getHealthDataFromTypes sends for [samples] of the data type [type].
  private func maps(of samples: [HKSample], type: String, unit: HKUnit? = nil) throws -> [NSDictionary] {
    var result: Result<[Any], Error>?
    reader.convertSamples(samples, dataTypeKey: type, unit: unit, includeManualEntry: true) { result = $0 }
    return try XCTUnwrap(result).get().map { try XCTUnwrap($0 as? NSDictionary) }
  }
}
