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

  func testSeriesSamplesGiveAPointPerReading() throws {
    let bpm = HKUnit.count().unitDivided(by: .minute())
    func sample(average: Double, from: TimeInterval, to: TimeInterval) -> HKQuantitySample {
      HKQuantitySample(
        type: HKQuantityType(.heartRate), quantity: HKQuantity(unit: bpm, doubleValue: average),
        start: start + from, end: start + to, metadata: [HKMetadataKeyHeartRateMotionContext: 2]
      )
    }
    func reading(_ value: Double, from: TimeInterval, to: TimeInterval) -> SeriesReading {
      SeriesReading(
        quantity: HKQuantity(unit: bpm, doubleValue: value),
        interval: DateInterval(start: start + from, end: start + to)
      )
    }
    let series = sample(average: 150, from: 0, to: 300)
    let single = sample(average: 160, from: 300, to: 300)
    // HealthKit merges equal consecutive readings into one interval.
    let readings = [series.uuid: [reading(140, from: 0, to: 0), reading(155, from: 5, to: 20), reading(169, from: 300, to: 300)]]

    let oldestFirst = reader.quantityDictionaries(
      [series, single], unit: bpm, readings: readings, newestFirst: false
    )
    XCTAssertEqual(oldestFirst.map { $0["value"] as? Double }, [140, 155, 169, 160])
    XCTAssertEqual(oldestFirst.map { $0["date_from"] as? Int }, [0, 5, 300, 300].map(millis))
    XCTAssertEqual(oldestFirst.map { $0["date_to"] as? Int }, [0, 20, 300, 300].map(millis))
    // A reading keeps its sample's UUID and metadata.
    XCTAssertEqual(oldestFirst[1]["uuid"] as? String, "\(series.uuid)")
    XCTAssertEqual((oldestFirst[1]["metadata"] as? [String: Any])?[HKMetadataKeyHeartRateMotionContext] as? Int, 2)

    let newestFirst = reader.quantityDictionaries(
      [single, series], unit: bpm, readings: readings, newestFirst: true
    )
    XCTAssertEqual(newestFirst.map { $0["value"] as? Double }, [160, 169, 155, 140])

    // Without readings, e.g. for a read by UUID, a sample gives its summary value.
    XCTAssertEqual(reader.quantityDictionaries([series], unit: bpm).map { $0["value"] as? Double }, [150])
  }

  func testPagesHoldAtMostPageSizePoints() {
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [1, 1, 1], limit: 3), 3)
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [1, 1, 1, 1], limit: 3), 3)
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [60, 60, 60], limit: 130), 2)
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [60, 60, 10], limit: 130), 3)
    // A page holds its first sample, however many readings it has.
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [60, 1], limit: 10), 1)
    XCTAssertEqual(HealthDataReader.pageLength(pointCounts: [], limit: 10), 0)
  }

  private func millis(_ offset: TimeInterval) -> Int {
    Int((start + offset).timeIntervalSince1970 * 1000)
  }

  /// The maps that getHealthDataFromTypes sends for [samples] of the data type [type].
  private func maps(of samples: [HKSample], type: String, unit: HKUnit? = nil) throws -> [NSDictionary] {
    var result: Result<[Any], Error>?
    reader.convertSamples(samples, dataTypeKey: type, unit: unit, includeManualEntry: true) { result = $0 }
    return try XCTUnwrap(result).get().map { try XCTUnwrap($0 as? NSDictionary) }
  }
}
