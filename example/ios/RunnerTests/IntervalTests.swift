import Flutter
import HealthKit
import XCTest

@testable import health

/// Interval data: heart rate is the average per bucket, a sleep type or MINDFULNESS the minutes of
/// each bucket its samples cover, overlapping samples counted once, from the apps of those samples.
/// Buckets without data are left out.
class IntervalTests: XCTestCase {
  private let reader: HealthDataReader = {
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    return HealthDataReader(
      healthStore: plugin.healthStore, dataTypesDict: plugin.dataTypesDict,
      dataQuantityTypesDict: plugin.dataQuantityTypesDict, unitDict: plugin.unitDict,
      workoutActivityTypeMap: plugin.workoutActivityTypeMap,
      characteristicsTypesDict: plugin.characteristicsTypesDict
    )
  }()
  /// The start of the reads below, in milliseconds since the epoch.
  private let t0 = 1_700_000_000_000
  private let minute = 60_000
  /// The source of the intervals below that name none.
  private let app = "com.example.sleep"

  func testIntervalInsideOneBucket() {
    XCTAssertEqual(buckets([(10, 40)]), [bucket(0, 60, covered: 30)])
  }

  func testIntervalOverSeveralBuckets() {
    XCTAssertEqual(
      buckets([(30, 150)]),
      [
        bucket(0, 60, covered: 30),
        bucket(60, 120, covered: 60),
        bucket(120, 180, covered: 30),
      ]
    )
  }

  func testOverlappingIntervalsCountOnce() {
    XCTAssertEqual(buckets([(0, 30), (15, 45)]), [bucket(0, 60, covered: 45)])
    XCTAssertEqual(buckets([(10, 20), (10, 20)]), [bucket(0, 60, covered: 10)])
    XCTAssertEqual(
      buckets([(0, 120), (30, 60)]),
      [bucket(0, 60, covered: 60), bucket(60, 120, covered: 60)]
    )
  }

  func testBucketsWithoutDataAreLeftOut() {
    XCTAssertEqual(
      buckets([(10, 20), (130, 140)]),
      [bucket(0, 60, covered: 10), bucket(120, 180, covered: 10)]
    )
    XCTAssertEqual(buckets([(30, 30)]), [])
    XCTAssertEqual(buckets([]), [])
  }

  func testIntervalsAreClippedToTheRead() {
    XCTAssertEqual(buckets([(-30, 30)]), [bucket(0, 60, covered: 30)])
    XCTAssertEqual(buckets([(170, 400)]), [bucket(120, 180, covered: 10)])
    XCTAssertEqual(buckets([(-60, 0), (180, 240)]), [])
  }

  func testLastBucketEndsAtTheEndOfTheRead() {
    XCTAssertEqual(
      buckets([(0, 200)], end: 150),
      [
        bucket(0, 60, covered: 60),
        bucket(60, 120, covered: 60),
        bucket(120, 150, covered: 30),
      ]
    )
    // An interval argument too long for Int milliseconds, which the reader passes as Int.max.
    let interval = [(start: t0, end: t0 + 10 * minute, source: app)]
    XCTAssertEqual(
      HealthDataReader.minutesPerBucket(interval, start: t0, end: t0 + 150 * minute, bucket: .max),
      [bucket(0, 150, covered: 10)]
    )
  }

  func testBucketsListTheSourcesOfTheirIntervals() {
    // In the order the intervals start, unsorted as samples may come, each source once, also that
    // of an interval which earlier ones cover entirely.
    XCTAssertEqual(
      buckets(of: [(20, 50, "b"), (10, 30, "a"), (55, 130, "c"), (25, 35, "a")]),
      [
        bucket(0, 60, covered: 45, sources: ["a", "b", "c"]),
        bucket(60, 120, covered: 60, sources: ["c"]),
        bucket(120, 180, covered: 10, sources: ["c"]),
      ]
    )
    // An interval inside another adds its source but no time.
    XCTAssertEqual(
      buckets(of: [(0, 120, "a"), (70, 80, "b")]),
      [bucket(0, 60, covered: 60, sources: ["a"]), bucket(60, 120, covered: 60, sources: ["a", "b"])]
    )
  }

  func testBucketsListASourceOnce() {
    // A later interval of a source lists it in the buckets that its earlier ones do not reach.
    XCTAssertEqual(
      buckets(of: [(0, 70, "a"), (50, 65, "b"), (60, 150, "a"), (100, 110, "b"), (170, 175, "a")]),
      [
        bucket(0, 60, covered: 60, sources: ["a", "b"]),
        bucket(60, 120, covered: 60, sources: ["a", "b"]),
        bucket(120, 180, covered: 35, sources: ["a"]),
      ]
    )
  }

  func testSourcesOfIntervalsOutsideTheReadAreLeftOut() {
    // Clipped intervals in the order they start; empty ones and those outside the read list none.
    XCTAssertEqual(
      buckets(of: [(-30, 30, "b"), (-60, 10, "a"), (-60, 0, "x"), (40, 40, "y"), (180, 240, "z")]),
      [bucket(0, 60, covered: 30, sources: ["a", "b"])]
    )
  }

  func testEmptyReads() {
    XCTAssertEqual(buckets([(10, 20)], end: 0), [])
    let interval = [(start: t0 + 10 * minute, end: t0 + 20 * minute, source: app)]
    XCTAssertEqual(
      HealthDataReader.minutesPerBucket(interval, start: t0, end: t0 + 180 * minute, bucket: 0), []
    )
  }

  func testMinutes() {
    XCTAssertEqual(bucket(0, 60, covered: 45).minutes, 45)
    let short = IntervalBucket(start: 0, end: minute, covered: 1_500, sources: [])
    XCTAssertEqual(short.minutes, 0.025)
  }

  func testEverySleepTypeHasSleepIntervals() {
    // A sleep type replies to a unit that is no unit of time before reading anything. The
    // headache severities are category values too, but have no interval data.
    let arguments: [String: Any] = [
      "dataUnitKey": "METER", "interval": 3600, "startTime": t0, "endTime": t0 + 24 * 60 * minute,
    ]
    for dataTypeKey in Array(CategoryValues.sleepValues.keys) + ["SLEEP_UNKNOWN"] {
      let sent = intervalReplies(arguments.merging(["dataTypeKey": dataTypeKey]) { $1 })
      XCTAssertEqual(sent.count, 1, dataTypeKey)
      XCTAssertEqual((sent.first as? FlutterError)?.message, "Unit METER cannot be used for \(dataTypeKey)")
    }
    for dataTypeKey in CategoryValues.headacheValues.keys {
      let sent = intervalReplies(arguments.merging(["dataTypeKey": dataTypeKey]) { $1 })
      XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_TYPE", dataTypeKey)
    }
  }

  func testSleepIntervalsCheckTheirArguments() {
    // Before reading anything, so these replies come before the call returns.
    let arguments: [String: Any] = [
      "dataTypeKey": "SLEEP_DEEP", "dataUnitKey": "MINUTE", "interval": 3600,
      "startTime": t0, "endTime": t0 + 24 * 60 * minute,
    ]
    let wrongUnit = intervalReplies(arguments.merging(["dataUnitKey": "METER"]) { $1 })
    XCTAssertEqual(wrongUnit.count, 1)
    let error = wrongUnit.first as? FlutterError
    XCTAssertEqual(error?.code, "INVALID_ARGUMENT")
    XCTAssertEqual(error?.message, "Unit METER cannot be used for SLEEP_DEEP")
    let noInterval = intervalReplies(arguments.merging(["interval": 0]) { $1 })
    XCTAssertEqual((noInterval.first as? FlutterError)?.code, "INVALID_ARGUMENT")
    let emptyRead = intervalReplies(arguments.merging(["endTime": t0]) { $1 })
    XCTAssertEqual(emptyRead.count, 1)
    XCTAssertEqual((emptyRead.first as? [Any])?.count, 0)
  }

  func testTypesThisIOSLacksAreNotSupported() {
    // As before iOS 18, which has no rowing speed: the plugin does not register it.
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    var dataTypes = plugin.dataTypesDict
    var quantityTypes = plugin.dataQuantityTypesDict
    dataTypes["ROWING_SPEED"] = nil
    quantityTypes["ROWING_SPEED"] = nil
    let olderReader = HealthDataReader(
      healthStore: plugin.healthStore, dataTypesDict: dataTypes, dataQuantityTypesDict: quantityTypes,
      unitDict: plugin.unitDict, workoutActivityTypeMap: [:],
      characteristicsTypesDict: plugin.characteristicsTypesDict
    )
    func code(_ dataTypeKey: String, paged: Bool = false) -> String? {
      let arguments: [String: Any] = [
        "dataTypeKey": dataTypeKey, "dataUnitKey": "METER_PER_SECOND", "interval": 3600,
        "startTime": t0, "endTime": t0 + 60 * minute,
      ]
      let sent = paged
        ? replies(to: olderReader.getDataPage, method: "getDataPage", arguments: arguments)
        : replies(to: olderReader.getIntervalData, method: "getIntervalData", arguments: arguments)
      XCTAssertEqual(sent.count, 1, dataTypeKey)
      return (sent.first as? FlutterError)?.code
    }
    // As a paged read of it replies.
    XCTAssertEqual(code("ROWING_SPEED"), "NOT_SUPPORTED")
    XCTAssertEqual(code("ROWING_SPEED", paged: true), "NOT_SUPPORTED")
    // And as a read by UUID of it.
    let byUUID = replies(
      to: olderReader.getDataByUUID, method: "getDataByUUID",
      arguments: ["dataTypeKey": "ROWING_SPEED", "uuid": UUID().uuidString]
    )
    XCTAssertEqual(byUUID.count, 1)
    XCTAssertEqual((byUUID.first as? FlutterError)?.code, "NOT_SUPPORTED")
    // The types this iOS has without interval data keep their code.
    XCTAssertEqual(code("WORKOUT"), "INVALID_TYPE")
    XCTAssertEqual(code("APPLE_STAND_HOUR"), "INVALID_TYPE")
    XCTAssertEqual(code("GENDER"), "INVALID_TYPE")
  }

  func testQuantitiesAreSummedOrAveraged() {
    XCTAssertEqual(reader.statisticsOption(for: "HEART_RATE"), .discreteAverage)
    XCTAssertEqual(reader.statisticsOption(for: "STEPS"), .cumulativeSum)
    XCTAssertEqual(reader.statisticsOption(for: "VO2_MAX"), .discreteAverage)
  }

  func testVo2MaxIsInMillilitersPerKilogramPerMinute() throws {
    let type = try XCTUnwrap(reader.dataQuantityTypesDict["VO2_MAX"])
    XCTAssertEqual(reader.dataTypesDict["VO2_MAX"], type)
    let unit = try XCTUnwrap(reader.unitDict["MILLILITER_PER_KILOGRAM_PER_MINUTE"])
    XCTAssertTrue(type.is(compatibleWith: unit))
    let perKilogramPerMinute = HKUnit.literUnit(with: .milli)
      .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
    XCTAssertEqual(
      HKQuantity(unit: unit, doubleValue: 42.5).doubleValue(for: perKilogramPerMinute), 42.5, accuracy: 1e-9
    )
  }

  /// The hour buckets of [intervals] (in minutes after t0) of the app in a read from t0 to
  /// [end] minutes after it.
  private func buckets(_ intervals: [(Int, Int)], end: Int = 180) -> [IntervalBucket] {
    buckets(of: intervals.map { ($0.0, $0.1, app) }, end: end)
  }

  /// The hour buckets of [intervals] (in minutes after t0, and their source) in a read from t0
  /// to [end] minutes after it.
  private func buckets(of intervals: [(Int, Int, String)], end: Int = 180) -> [IntervalBucket] {
    HealthDataReader.minutesPerBucket(
      intervals.map { (start: t0 + $0.0 * minute, end: t0 + $0.1 * minute, source: $0.2) },
      start: t0, end: t0 + end * minute, bucket: 60 * minute
    )
  }

  /// A bucket from [start] to [end] minutes after t0 of which [covered] minutes are covered by
  /// the intervals of [sources] (the app by default).
  private func bucket(_ start: Int, _ end: Int, covered: Int, sources: [String]? = nil) -> IntervalBucket {
    IntervalBucket(
      start: t0 + start * minute, end: t0 + end * minute, covered: covered * minute, sources: sources ?? [app]
    )
  }

  /// The replies getIntervalData sends before it returns.
  private func intervalReplies(_ arguments: [String: Any]) -> [Any?] {
    replies(to: reader.getIntervalData, method: "getIntervalData", arguments: arguments)
  }
}
