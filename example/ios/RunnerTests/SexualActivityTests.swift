import Flutter
import HealthKit
import XCTest

@testable import health

/// SEXUAL_ACTIVITY maps to HealthKit's HKCategoryTypeIdentifier.sexualActivity with
/// HKMetadataKeySexualActivityProtectionUsed for protection status.
class SexualActivityTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  private func initializedPlugin() -> HealthPlugin {
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    return plugin
  }

  func testSexualActivityIsRegisteredAsCategoryType() throws {
    let plugin = initializedPlugin()
    let sampleType = try XCTUnwrap(plugin.dataTypesDict[HealthConstants.SEXUAL_ACTIVITY])
    XCTAssertEqual(sampleType, HKSampleType.categoryType(forIdentifier: .sexualActivity))
  }

  func testConvertsSamplesWithAndWithoutProtectionMetadata() throws {
    let plugin = initializedPlugin()
    let reader = HealthDataReader(
      healthStore: plugin.healthStore,
      dataTypesDict: plugin.dataTypesDict,
      dataQuantityTypesDict: plugin.dataQuantityTypesDict,
      unitDict: plugin.unitDict,
      workoutActivityTypeMap: [:],
      characteristicsTypesDict: [:]
    )
    let type = HKCategoryType(.sexualActivity)
    let protectedSample = HKCategorySample(
      type: type,
      value: HKCategoryValue.notApplicable.rawValue,
      start: start,
      end: start,
      metadata: [
        HKMetadataKeySexualActivityProtectionUsed: NSNumber(value: true),
        HKMetadataKeyWasUserEntered: NSNumber(value: true),
      ]
    )
    let unprotectedSample = HKCategorySample(
      type: type,
      value: HKCategoryValue.notApplicable.rawValue,
      start: start,
      end: start,
      metadata: [HKMetadataKeySexualActivityProtectionUsed: NSNumber(value: false)]
    )
    let unspecifiedSample = HKCategorySample(
      type: type,
      value: HKCategoryValue.notApplicable.rawValue,
      start: start,
      end: start,
      metadata: nil
    )

    var result: Result<[Any], Error>?
    reader.convertSamples(
      [protectedSample, unprotectedSample, unspecifiedSample],
      dataTypeKey: HealthConstants.SEXUAL_ACTIVITY,
      unit: nil,
      includeManualEntry: true
    ) { result = $0 }

    let maps = try XCTUnwrap(result).get().map { try XCTUnwrap($0 as? NSDictionary) }
    XCTAssertEqual(maps.count, 3)

    let protectedMeta = try XCTUnwrap(maps[0]["metadata"] as? [String: Any])
    XCTAssertEqual((protectedMeta[HKMetadataKeySexualActivityProtectionUsed] as? NSNumber)?.boolValue, true)
    XCTAssertEqual(maps[0]["recording_method"] as? Int, HealthConstants.RecordingMethod.manual.rawValue)

    let unprotectedMeta = try XCTUnwrap(maps[1]["metadata"] as? [String: Any])
    XCTAssertEqual((unprotectedMeta[HKMetadataKeySexualActivityProtectionUsed] as? NSNumber)?.boolValue, false)
    XCTAssertEqual(maps[1]["recording_method"] as? Int, HealthConstants.RecordingMethod.automatic.rawValue)

    let unspecifiedMeta = try XCTUnwrap(maps[2]["metadata"] as? [String: Any])
    XCTAssertNil(unspecifiedMeta[HKMetadataKeySexualActivityProtectionUsed])
  }

  func testWriteSexualActivitySavesSamplesWithExpectedMetadata() throws {
    let store = RecordingHealthStore()
    let plugin = initializedPlugin()
    let writer = HealthDataWriter(
      healthStore: store,
      dataTypesDict: plugin.dataTypesDict,
      unitDict: plugin.unitDict,
      workoutActivityTypeMap: [:]
    )

    let cases: [(Any, Bool?, Int)] = [
      (true, true, HealthConstants.RecordingMethod.manual.rawValue),
      (false, false, HealthConstants.RecordingMethod.automatic.rawValue),
      (NSNull(), nil, HealthConstants.RecordingMethod.manual.rawValue),
    ]

    for (rawProtection, expectedProtection, recordingMethod) in cases {
      let expectation = expectation(description: "writeSexualActivity replies")
      var reply: Any?
      let call = FlutterMethodCall(
        methodName: "writeSexualActivity",
        arguments: [
          "protectionUsed": rawProtection,
          "startTime": milliseconds(start),
          "endTime": milliseconds(start + 60),
          "recordingMethod": recordingMethod,
        ]
      )
      try writer.writeSexualActivity(call: call) {
        reply = $0
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 2)
      XCTAssertEqual(reply as? Bool, true)

      let sample = try XCTUnwrap(store.saved.last as? HKCategorySample)
      XCTAssertEqual(sample.categoryType, HKCategoryType(.sexualActivity))
      XCTAssertEqual(sample.value, HKCategoryValue.notApplicable.rawValue)
      XCTAssertEqual(sample.startDate.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
      XCTAssertEqual(sample.endDate.timeIntervalSince1970, (start + 60).timeIntervalSince1970, accuracy: 0.001)

      let actualProtection = (sample.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? NSNumber)?.boolValue
      XCTAssertEqual(actualProtection, expectedProtection)

      let expectedManual = recordingMethod == HealthConstants.RecordingMethod.manual.rawValue
      XCTAssertEqual((sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber)?.boolValue, expectedManual)
    }
  }

  func testWriteSexualActivityRejectsInvalidArgumentsAndDates() throws {
    let store = RecordingHealthStore()
    let plugin = initializedPlugin()
    let writer = HealthDataWriter(
      healthStore: store,
      dataTypesDict: plugin.dataTypesDict,
      unitDict: plugin.unitDict,
      workoutActivityTypeMap: [:]
    )

    // Non-boolean protectionUsed throws PluginError.
    let invalidProtection = FlutterMethodCall(
      methodName: "writeSexualActivity",
      arguments: [
        "protectionUsed": 1,
        "startTime": milliseconds(start),
        "endTime": milliseconds(start),
        "recordingMethod": 3,
      ]
    )
    XCTAssertNotNil(pluginErrorMessage(try writer.writeSexualActivity(call: invalidProtection) { _ in }))

    // Start after end replies INVALID_ARGUMENT once without saving.
    let invertedDates = try replies(
      to: writer.writeSexualActivity,
      method: "writeSexualActivity",
      arguments: [
        "protectionUsed": true,
        "startTime": milliseconds(start + 60),
        "endTime": milliseconds(start),
        "recordingMethod": 3,
      ]
    )
    XCTAssertEqual(invertedDates.count, 1)
    XCTAssertEqual((invertedDates.first as? FlutterError)?.code, "INVALID_ARGUMENT")

    // Distant future replies INVALID_ARGUMENT once without saving.
    let futureDates = try replies(
      to: writer.writeSexualActivity,
      method: "writeSexualActivity",
      arguments: [
        "protectionUsed": NSNull(),
        "startTime": milliseconds(.distantFuture),
        "endTime": milliseconds(.distantFuture),
        "recordingMethod": 3,
      ]
    )
    XCTAssertEqual(futureDates.count, 1)
    XCTAssertEqual((futureDates.first as? FlutterError)?.code, "INVALID_ARGUMENT")
    XCTAssertTrue(store.saved.isEmpty)
  }
}
