import Flutter
import HealthKit
import XCTest

@testable import health

/// HealthKit raises an exception (crashing the app) for a sample whose time range its type does
/// not accept and for a meal without nutrients, so writes check these before they create a sample
/// and reply one INVALID_ARGUMENT error instead.
class SampleDatesTests: XCTestCase {
  private typealias Write = (FlutterMethodCall, @escaping FlutterResult) throws -> Void

  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(),
    dataTypesDict: [
      "STEPS": HKQuantityType(.stepCount),
      "SLEEP_ASLEEP": HKCategoryType(.sleepAnalysis),
      "MINDFULNESS": HKCategoryType(.mindfulSession),
      "ENVIRONMENTAL_AUDIO_EXPOSURE": HKQuantityType(.environmentalAudioExposure),
    ],
    unitDict: [
      "COUNT": .count(), "DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL": .decibelAWeightedSoundPressureLevel(),
    ],
    workoutActivityTypeMap: [:]
  )
  private let now = Date()
  private let day: TimeInterval = 24 * 60 * 60

  func testAcceptsTheLongestRangeOfEachType() {
    // Steps can last 4 days, a mindfulness session 28; menstrual flow has no maximum.
    let ranges: [(HKSampleType, TimeInterval)] = [
      (HKQuantityType(.stepCount), 4 * day),
      (HKCategoryType(.mindfulSession), 28 * day),
      (HKCategoryType(.menstrualFlow), 365 * day),
    ]
    for (type, duration) in ranges {
      var sent = [Any?]()
      let accepted = writer.validateSampleDates(start: now - duration, end: now, of: [type]) {
        sent.append($0)
      }
      XCTAssertTrue(accepted, type.identifier)
      XCTAssertTrue(sent.isEmpty, type.identifier)
    }
  }

  func testAudioExposuresLastAtLeastAMillisecond() throws {
    // At one instant, as writeHealthData writes a sample without an endTime.
    let instant: [String: Any] = [
      "value": 70.0, "dataTypeKey": "ENVIRONMENTAL_AUDIO_EXPOSURE",
      "dataUnitKey": "DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL", "recordingMethod": 2,
      "startTime": milliseconds(now), "endTime": milliseconds(now),
    ]
    try assertRepliesInvalidArgumentOnce(writer.writeData, method: "writeData", arguments: instant)
    try assertRepliesInvalidArgumentOnce(writer.writeDataUUID, method: "writeDataUUID", arguments: instant)
    for type in [HKQuantityType(.environmentalAudioExposure), HKQuantityType(.headphoneAudioExposure)] {
      XCTAssertEqual(
        pluginErrorMessage(try writer.checkSampleDates(start: now, end: now, of: type)),
        "A \(type.identifier) sample must last at least 0.001 seconds"
      )
      var sent = [Any?]()
      XCTAssertTrue(writer.validateSampleDates(start: now - 1, end: now, of: [type]) { sent.append($0) })
      XCTAssertTrue(sent.isEmpty, type.identifier)
    }
  }

  func testTooLongSamplesReplyOnce() throws {
    let steps: [String: Any] = [
      "value": 10.0, "dataTypeKey": "STEPS", "dataUnitKey": "COUNT", "recordingMethod": 2,
    ]
    let sleep: [String: Any] = [
      "value": 1.0, "dataTypeKey": "SLEEP_ASLEEP", "dataUnitKey": "MINUTE", "recordingMethod": 2,
    ]
    // 29 days: one more than a mindfulness session can last.
    let mindfulness: [String: Any] = [
      "value": 0.0, "dataTypeKey": "MINDFULNESS", "dataUnitKey": "MINUTE", "recordingMethod": 2,
      "startTime": milliseconds(now - 29 * day), "endTime": milliseconds(now),
    ]
    let bloodPressure: [String: Any] = ["systolic": 120.0, "diastolic": 80.0, "recordingMethod": 2]
    let insulin: [String: Any] = ["units": 2.0, "reason": 1]
    let meal: [String: Any] = [
      "name": "Lunch", "meal_type": "LUNCH", "recordingMethod": 2, "calories": 500.0,
      "start_time": milliseconds(now - 5 * day), "end_time": milliseconds(now),
    ]
    let writes: [(String, Write, [String: Any])] = [
      ("writeData", writer.writeData, overFiveDays(steps)),
      ("writeDataUUID", writer.writeDataUUID, overFiveDays(steps)),
      ("writeData", writer.writeData, overFiveDays(sleep)),
      ("writeData", writer.writeData, mindfulness),
      ("writeDataUUID", writer.writeDataUUID, mindfulness),
      ("writeMindfulness", writer.writeMindfulness, mindfulness),
      ("writeBloodPressure", writer.writeBloodPressure, overFiveDays(bloodPressure)),
      ("writeMeal", writer.writeMeal, meal),
      ("writeInsulinDelivery", writer.writeInsulinDelivery, overFiveDays(insulin)),
    ]
    for (method, write, arguments) in writes {
      try assertRepliesInvalidArgumentOnce(write, method: method, arguments: arguments)
    }
  }

  func testMealWithoutNutrientsRepliesOnce() throws {
    // As the Dart side sends it: null for each nutrient not set. HealthKit has no type for trans
    // fat, so a meal with only that has no nutrient sample either.
    let meal: [String: Any] = [
      "name": "Lunch", "meal_type": "LUNCH", "recordingMethod": 2, "calories": NSNull(),
      "start_time": milliseconds(now), "end_time": milliseconds(now),
    ]
    try assertRepliesInvalidArgumentOnce(writer.writeMeal, method: "writeMeal", arguments: meal)
    try assertRepliesInvalidArgumentOnce(
      writer.writeMeal, method: "writeMeal",
      arguments: meal.merging(["fat_trans_monoenoic": 1.0]) { $1 }
    )
  }

  func testMealTakesThiaminAndNoName() throws {
    // Only thiamin, over 5 days, and no name or meal type (null, as the Dart side sends them):
    // the reply is about the thiamin sample, not about the arguments or a meal without nutrients.
    let sent = try replies(
      to: writer.writeMeal, method: "writeMeal",
      arguments: [
        "name": NSNull(), "meal_type": NSNull(), "recordingMethod": 2, "b1_thiamine": 0.001,
        "start_time": milliseconds(now - 5 * day), "end_time": milliseconds(now),
      ]
    )
    XCTAssertEqual(sent.count, 1)
    let message = try XCTUnwrap((sent.first as? FlutterError)?.message)
    XCTAssertTrue(message.hasPrefix("A HKQuantityTypeIdentifierDietaryThiamin sample can last"), message)
  }

  func testEndAtDistantFutureRepliesOnce() throws {
    let distantFuture = milliseconds(.distantFuture)
    try assertRepliesInvalidArgumentOnce(
      writer.writeMenstruationFlow, method: "writeMenstruationFlow",
      arguments: [
        "value": 2, "endTime": distantFuture, "isStartOfCycle": false, "recordingMethod": 3,
      ]
    )
    try assertRepliesInvalidArgumentOnce(
      writer.writeData, method: "writeData",
      arguments: [
        "value": 10.0, "dataTypeKey": "STEPS", "dataUnitKey": "COUNT", "recordingMethod": 2,
        "startTime": distantFuture, "endTime": distantFuture,
      ]
    )
  }

  func testStartAfterEndRepliesOnce() throws {
    try assertRepliesInvalidArgumentOnce(
      writer.writeInsulinDelivery, method: "writeInsulinDelivery",
      arguments: [
        "units": 2.0, "reason": 1, "startTime": milliseconds(now),
        "endTime": milliseconds(now - 60),
      ]
    )
  }

  /// [arguments] for a sample over the 5 days before now, one more than most types allow.
  private func overFiveDays(_ arguments: [String: Any]) -> [String: Any] {
    let range = ["startTime": milliseconds(now - 5 * day), "endTime": milliseconds(now)]
    return arguments.merging(range) { $1 }
  }

  /// Asserts that the write replies a single INVALID_ARGUMENT error before it returns. A write
  /// that went on would create the sample, which raises an exception and ends the test run.
  private func assertRepliesInvalidArgumentOnce(
    _ write: Write, method: String, arguments: [String: Any], line: UInt = #line
  ) throws {
    let sent = try replies(to: write, method: method, arguments: arguments)
    XCTAssertEqual(sent.count, 1, method, line: line)
    XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT", method, line: line)
  }
}
