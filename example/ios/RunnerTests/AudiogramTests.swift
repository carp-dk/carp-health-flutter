import Flutter
import HealthKit
import XCTest

@testable import health

/// HKAudiogramSample raises an exception (crashing the app) for points, dates or metadata it does
/// not accept, so the writer checks them first. Reads give nil for an ear without a test.
class AudiogramTests: XCTestCase {
  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:], unitDict: [:], workoutActivityTypeMap: [:]
  )
  private let now = Date()
  private let day: TimeInterval = 24 * 60 * 60

  func testAcceptsThirtyFrequenciesOverFourDays() throws {
    let sample = try audiogram(frequencies: frequencies(30), lasting: 4 * day)
    XCTAssertEqual(sample.sensitivityPoints.count, 30)
  }

  func testRejectsMoreThanThirtyFrequencies() {
    XCTAssertEqual(
      pluginErrorMessage(try audiogram(frequencies: frequencies(31))),
      "An audiogram can have at most 30 frequencies"
    )
  }

  func testRejectsDescendingFrequencies() {
    XCTAssertEqual(
      pluginErrorMessage(try audiogram(frequencies: [2000, 1000])),
      "frequencies must be unique and in ascending order"
    )
  }

  func testRejectsMoreThanFourDays() {
    XCTAssertEqual(
      pluginErrorMessage(try audiogram(frequencies: [1000], lasting: 5 * day)),
      "A HKDataTypeIdentifierAudiogram sample can last at most 345600 seconds"
    )
  }

  func testRejectsEndAtDistantFuture() {
    XCTAssertEqual(
      pluginErrorMessage(try audiogram(frequencies: [1000], endingAt: .distantFuture)),
      "endTime is too far in the future"
    )
  }

  func testRejectsNumericDeviceName() {
    XCTAssertEqual(
      pluginErrorMessage(try writer.audiogramMetadata(from: [HKMetadataKeyDeviceName: 3])),
      "metadata HKDeviceName must be a String"
    )
  }

  func testMetadataKeysAreOptional() throws {
    let metadata = try writer.audiogramMetadata(
      from: [HKMetadataKeyDeviceName: NSNull(), HKMetadataKeyExternalUUID: "external id"] as [String: Any]
    )
    XCTAssertEqual(metadata as? [String: String], [HKMetadataKeyExternalUUID: "external id"])
  }

  func testTooLongAudiogramRepliesOnce() throws {
    let sent = try replies(
      to: writer.writeAudiogram, method: "writeAudiogram",
      arguments: [
        "frequencies": [1000.0], "leftEarSensitivities": [20.0], "rightEarSensitivities": [20.0],
        "startTime": milliseconds(now - 5 * day), "endTime": milliseconds(now),
      ]
    )
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT")
  }

  func testEarWithoutTestReadsAsNil() throws {
    let reader = HealthDataReader(
      healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
      workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
    )
    let point = try HKAudiogramSensitivityPoint(
      frequency: HKQuantity(unit: .hertz(), doubleValue: 1000),
      leftEarSensitivity: nil,
      rightEarSensitivity: HKQuantity(unit: .decibelHearingLevel(), doubleValue: 30)
    )
    let sensitivities = reader.earSensitivities(of: point)
    XCTAssertNil(sensitivities.left)
    XCTAssertEqual(sensitivities.right?.doubleValue(for: .decibelHearingLevel()), 30)
  }

  /// Frequencies of 100, 200, ... Hz.
  private func frequencies(_ count: Int) -> [Double] {
    (1...count).map { Double($0 * 100) }
  }

  /// An audiogram with the same sensitivity at every frequency in both ears.
  private func audiogram(
    frequencies: [Double], lasting duration: TimeInterval = 0, endingAt end: Date? = nil
  ) throws -> HKAudiogramSample {
    let end = end ?? now
    let decibels = [Double](repeating: 20, count: frequencies.count)
    return try writer.audiogramSample(
      frequencies: frequencies, leftEarSensitivities: decibels, rightEarSensitivities: decibels,
      start: end - duration, end: end, metadata: nil
    )
  }
}
