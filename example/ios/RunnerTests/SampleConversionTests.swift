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

  func testSamplesHaveTheModelOfTheirDevice() throws {
    let watch = HKDevice(
      name: "Apple Watch", manufacturer: "Apple Inc.", model: "Watch", hardwareVersion: "Watch7,1",
      firmwareVersion: nil, softwareVersion: "26.0", localIdentifier: nil, udiDeviceIdentifier: nil
    )
    let end = start + 30 * 60
    let steps = [watch, nil].map {
      HKQuantitySample(
        type: HKQuantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: 1200),
        start: start, end: end, device: $0, metadata: nil
      )
    }
    let mindfulness = [watch, nil].map {
      HKCategorySample(
        type: HKCategoryType(.mindfulSession), value: HKCategoryValue.notApplicable.rawValue,
        start: start, end: end, device: $0, metadata: nil
      )
    }
    let runs = [watch, nil].map {
      HKWorkout(
        activityType: .running, start: start, end: end, workoutEvents: nil, totalEnergyBurned: nil,
        totalDistance: nil, device: $0, metadata: nil
      )
    }
    for maps in [
      try self.maps(of: steps, type: HealthConstants.STEPS, unit: .count()),
      try self.maps(of: mindfulness, type: HealthConstants.MINDFULNESS),
      try self.maps(of: runs, type: HealthConstants.WORKOUT),
    ] {
      XCTAssertEqual(maps[0]["device_model"] as? String, "Watch")
      // Null on the Dart side when the app that wrote the data named no device.
      XCTAssertTrue(maps[1]["device_model"] is NSNull)
    }
  }

  /// The maps that getHealthDataFromTypes sends for [samples] of the data type [type].
  private func maps(of samples: [HKSample], type: String, unit: HKUnit? = nil) throws -> [NSDictionary] {
    var result: Result<[Any], Error>?
    reader.convertSamples(samples, dataTypeKey: type, unit: unit, includeManualEntry: true) { result = $0 }
    return try XCTUnwrap(result).get().map { try XCTUnwrap($0 as? NSDictionary) }
  }
}
