import Flutter
import HealthKit
import XCTest

@testable import health

/// MINDFULNESS is HealthKit's mindful session category: its interval data is the minutes of each
/// bucket that sessions cover, as for the sleep types but of every session, and writeDataUUID
/// replies the UUID of a session as it does for other types.
class MindfulnessTests: XCTestCase {
  private let plugin: HealthPlugin = {
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    return plugin
  }()
  private let store = RecordingHealthStore()
  private lazy var reader = HealthDataReader(
    healthStore: store, dataTypesDict: plugin.dataTypesDict,
    dataQuantityTypesDict: plugin.dataQuantityTypesDict, unitDict: plugin.unitDict,
    workoutActivityTypeMap: [:], characteristicsTypesDict: plugin.characteristicsTypesDict
  )
  /// The start of the reads below, in milliseconds since the epoch.
  private let t0 = 1_700_000_000_000
  private let minute = 60_000

  func testMindfulnessCoversEverySession() throws {
    let mindfulness = try XCTUnwrap(reader.coverageCategory(for: "MINDFULNESS"))
    XCTAssertEqual(mindfulness, CoverageCategory(type: HKCategoryType(.mindfulSession), values: nil))
    XCTAssertTrue(mindfulness.contains(session(10, 20)))
    // A sleep type covers the samples of its value only.
    let deep = try XCTUnwrap(reader.coverageCategory(for: "SLEEP_DEEP"))
    XCTAssertEqual(deep, CoverageCategory(type: HKCategoryType(.sleepAnalysis), values: .only(4)))
    // Other types, also other categories, have no such intervals.
    for dataTypeKey in ["HEADACHE_MILD", "APPLE_STAND_HOUR", "STEPS", "WORKOUT", "GENDER"] {
      XCTAssertNil(reader.coverageCategory(for: dataTypeKey), dataTypeKey)
    }
  }

  func testMindfulnessIntervalsReadEverySession() throws {
    let mindfulness = try XCTUnwrap(executedQuery("MINDFULNESS"))
    XCTAssertEqual(mindfulness.objectType, HKCategoryType(.mindfulSession))
    // Without the value filter of a sleep type, and with the sessions the user entered.
    let predicate = try XCTUnwrap(mindfulness.predicate?.predicateFormat)
    XCTAssertFalse(predicate.contains(HKPredicateKeyPathCategoryValue), predicate)
    XCTAssertFalse(predicate.contains(HKMetadataKeyWasUserEntered), predicate)
    let deep = try XCTUnwrap(executedQuery("SLEEP_DEEP"))
    XCTAssertEqual(deep.objectType, HKCategoryType(.sleepAnalysis))
    XCTAssertTrue(deep.predicate?.predicateFormat.contains("\(HKPredicateKeyPathCategoryValue) == 4") ?? false)
    // Without them when manual entries are filtered out.
    let automatic = try XCTUnwrap(executedQuery("MINDFULNESS", filter: [3]))
    XCTAssertTrue(automatic.predicate?.predicateFormat.contains(HKMetadataKeyWasUserEntered) ?? false)
  }

  func testMindfulnessIntervalsAreInAUnitOfTime() {
    let sent = replies(
      to: reader.getIntervalData, method: "getIntervalData",
      arguments: [
        "dataTypeKey": "MINDFULNESS", "dataUnitKey": "METER", "interval": 3600,
        "startTime": t0, "endTime": t0 + 60 * minute,
      ]
    )
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT")
    XCTAssertEqual((sent.first as? FlutterError)?.message, "Unit METER cannot be used for MINDFULNESS")
    XCTAssertTrue(store.queries.isEmpty)
  }

  func testMindfulnessIntervalsAreTheTimeSessionsCover() {
    // Overlapping sessions count once; the hour without sessions is left out.
    let sessions = [session(10, 40), session(30, 70), session(190, 195)]
    let intervals = HealthDataReader.coverageIntervals(
      sessions, start: t0, end: t0 + 240 * minute, bucket: 60 * minute, unit: .minute()
    )
    XCTAssertEqual(intervals.map { $0["value"] as? Double }, [50, 10, 5])
    XCTAssertEqual(intervals.map { $0["date_from"] as? Int }, [0, 60, 180].map { t0 + $0 * minute })
    XCTAssertEqual(intervals.map { $0["date_to"] as? Int }, [60, 120, 240].map { t0 + $0 * minute })
    // No source id, as on Android. Unsaved sessions have no source app, so which apps source_name
    // joins is tested with minutesPerBucket (IntervalTests).
    XCTAssertEqual(intervals.map { $0["source_id"] as? String }, ["", "", ""])
    // In another unit of time.
    let seconds = HealthDataReader.coverageIntervals(
      sessions, start: t0, end: t0 + 240 * minute, bucket: 60 * minute, unit: .second()
    )
    XCTAssertEqual(seconds.map { $0["value"] as? Double }, [3000, 600, 300])
  }

  func testWriteDataUUIDRepliesTheSessionUUID() throws {
    let arguments: [String: Any] = [
      "value": 0.0, "dataTypeKey": "MINDFULNESS", "dataUnitKey": "MINUTE", "recordingMethod": 2,
      "startTime": milliseconds(Date() - 1200), "endTime": milliseconds(Date() - 600),
    ]
    for success in [true, false] {
      let store = RecordingHealthStore(saveSucceeds: success)
      let writer = HealthDataWriter(
        healthStore: store, dataTypesDict: plugin.dataTypesDict, unitDict: plugin.unitDict,
        workoutActivityTypeMap: [:]
      )
      let uuid = try reply(to: writer.writeDataUUID, method: "writeDataUUID", arguments: arguments)
      let saved = try XCTUnwrap(store.saved.last as? HKCategorySample)
      XCTAssertEqual(saved.categoryType, HKCategoryType(.mindfulSession))
      XCTAssertEqual(uuid as? String, success ? saved.uuid.uuidString : "")
      // writeData, which writeMindfulnessSession calls too, replies whether the session was saved.
      let wasSaved = try reply(to: writer.writeData, method: "writeData", arguments: arguments)
      XCTAssertEqual(wasSaved as? Bool, success)
      XCTAssertEqual(store.saved.count, 2)
    }
  }

  /// A mindful session from [start] to [end] minutes after t0, not saved.
  private func session(_ start: Int, _ end: Int) -> HKCategorySample {
    HKCategorySample(
      type: HKCategoryType(.mindfulSession), value: HKCategoryValue.notApplicable.rawValue,
      start: date(t0 + start * minute), end: date(t0 + end * minute)
    )
  }

  private func date(_ milliseconds: Int) -> Date {
    Date(timeIntervalSince1970: Double(milliseconds) / 1000)
  }

  /// The sample query an hour-long interval read of [dataTypeKey] in minutes runs, leaving out
  /// the recording methods [filter].
  private func executedQuery(_ dataTypeKey: String, filter: [Int] = []) -> HKSampleQuery? {
    let sent = replies(
      to: reader.getIntervalData, method: "getIntervalData",
      arguments: [
        "dataTypeKey": dataTypeKey, "dataUnitKey": "MINUTE", "interval": 3600,
        "startTime": t0, "endTime": t0 + 60 * minute, "recordingMethodsToFilter": filter,
      ]
    )
    // The reply comes once the query, which the store does not run, has results.
    XCTAssertTrue(sent.isEmpty, dataTypeKey)
    return store.queries.last as? HKSampleQuery
  }

  /// The one reply [write] sends, on the main queue.
  private func reply(
    to write: (FlutterMethodCall, @escaping FlutterResult) throws -> Void,
    method: String, arguments: [String: Any]
  ) throws -> Any? {
    let replied = expectation(description: method)
    replied.assertForOverFulfill = true
    var sent: Any?
    try write(FlutterMethodCall(methodName: method, arguments: arguments)) { reply in
      sent = reply
      replied.fulfill()
    }
    wait(for: [replied], timeout: 5)
    return sent
  }
}
