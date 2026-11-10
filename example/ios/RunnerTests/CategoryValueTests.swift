import Flutter
import HealthKit
import XCTest

@testable import health

/// The plugin's data types, as it registers them.
private let plugin: HealthPlugin = {
  let plugin = HealthPlugin()
  plugin.initializeTypes()
  return plugin
}()

/// The sleep types share HealthKit's sleepAnalysis type and the headache types its headache type,
/// so each covers its own values (CategoryValues) in reads, sleep intervals and deletes. Writes
/// reply an error for a sample HealthKit would raise an exception for (crashing the app).
class CategoryValueTests: XCTestCase {
  private typealias Write = (FlutterMethodCall, @escaping FlutterResult) throws -> Void

  private let reader = HealthDataReader(
    healthStore: plugin.healthStore, dataTypesDict: plugin.dataTypesDict,
    dataQuantityTypesDict: plugin.dataQuantityTypesDict, unitDict: plugin.unitDict,
    workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
  )
  private let writer = HealthDataWriter(
    healthStore: plugin.healthStore, dataTypesDict: plugin.dataTypesDict, unitDict: plugin.unitDict,
    workoutActivityTypeMap: [:]
  )
  private let operations = HealthDataOperations(
    healthStore: plugin.healthStore, dataTypesDict: plugin.dataTypesDict, characteristicsTypesDict: [:],
    nutritionList: []
  )
  private let sleepTypes = Array(CategoryValues.sleepValues.keys) + ["SLEEP_UNKNOWN"]
  private let headacheTypes = Array(CategoryValues.headacheValues.keys)
  private let now = Date()

  func testEachTypeCoversItsHealthKitValue() throws {
    let values: [String: Int] = [
      "SLEEP_IN_BED": HKCategoryValueSleepAnalysis.inBed.rawValue,
      "SLEEP_ASLEEP": HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
      "SLEEP_AWAKE": HKCategoryValueSleepAnalysis.awake.rawValue,
      "SLEEP_LIGHT": HKCategoryValueSleepAnalysis.asleepCore.rawValue,
      "SLEEP_DEEP": HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
      "SLEEP_REM": HKCategoryValueSleepAnalysis.asleepREM.rawValue,
      "HEADACHE_UNSPECIFIED": HKCategoryValueSeverity.unspecified.rawValue,
      "HEADACHE_NOT_PRESENT": HKCategoryValueSeverity.notPresent.rawValue,
      "HEADACHE_MILD": HKCategoryValueSeverity.mild.rawValue,
      "HEADACHE_MODERATE": HKCategoryValueSeverity.moderate.rawValue,
      "HEADACHE_SEVERE": HKCategoryValueSeverity.severe.rawValue,
    ]
    for (dataTypeKey, value) in values {
      XCTAssertEqual(CategoryValues(dataTypeKey), .only(value), dataTypeKey)
    }
    // Any other sleep analysis value, such as one Apple adds later.
    let unknown = try XCTUnwrap(CategoryValues("SLEEP_UNKNOWN"))
    XCTAssertEqual((-1...9).filter(unknown.contains), [-1, 6, 7, 8, 9])
    // A data type with a category type of its own covers all of its samples.
    for dataTypeKey in ["APPLE_STAND_HOUR", "MINDFULNESS", "MENSTRUATION_FLOW", "STEPS"] {
      XCTAssertNil(CategoryValues(dataTypeKey), dataTypeKey)
    }
  }

  func testEachValueBelongsToOneType() {
    let categoryTypes = plugin.dataTypesDict.filter { $0.value is HKCategoryType }
    let typesByCategory = Dictionary(grouping: categoryTypes.keys) { categoryTypes[$0]!.identifier }
    XCTAssertEqual(
      typesByCategory.filter { $0.value.count > 1 }.mapValues(Set.init),
      [
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: Set(sleepTypes),
        HKCategoryTypeIdentifier.headache.rawValue: Set(headacheTypes),
      ]
    )
    func coveringTypes(_ value: Int, of dataTypeKeys: [String]) -> Int {
      dataTypeKeys.filter { CategoryValues($0)?.contains(value) == true }.count
    }
    for value in -1...9 {
      XCTAssertEqual(coveringTypes(value, of: sleepTypes), 1, "\(value)")
    }
    for value in HKCategoryValueSeverity.unspecified.rawValue...HKCategoryValueSeverity.severe.rawValue {
      XCTAssertEqual(coveringTypes(value, of: headacheTypes), 1, "\(value)")
    }
  }

  func testPredicatesKeepWhatTheTestKeeps() throws {
    let groups: [(HKCategoryType, [String], ClosedRange<Int>)] = [
      (HKCategoryType(.sleepAnalysis), sleepTypes, 0...5),
      (HKCategoryType(.headache), headacheTypes, 0...4),
    ]
    for (type, dataTypeKeys, healthKitValues) in groups {
      for dataTypeKey in dataTypeKeys {
        let values = try XCTUnwrap(CategoryValues(dataTypeKey))
        XCTAssertEqual(
          samples(type, healthKitValues).filter { values.predicate.evaluate(with: $0) }.map(\.value),
          healthKitValues.filter(values.contains), dataTypeKey
        )
      }
    }
  }

  func testReadsTakeTheTypesValuesOnly() {
    // A read of HEADACHE_MILD gives the mild headaches, not every headache.
    let mild = readPredicate("HEADACHE_MILD")
    XCTAssertEqual(
      samples(HKCategoryType(.headache), 0...4).filter { mild.evaluate(with: $0) }.map(\.value),
      [HKCategoryValueSeverity.mild.rawValue]
    )
    // SLEEP_UNKNOWN gives none of the values the other sleep types give.
    let unknown = readPredicate("SLEEP_UNKNOWN")
    XCTAssertEqual(samples(HKCategoryType(.sleepAnalysis), 0...5).filter { unknown.evaluate(with: $0) }, [])
  }

  func testDeletesTakeTheTypesValuesOnly() throws {
    // Deleting SLEEP_REM deleted every sleep sample the app wrote in the range.
    let rem = try XCTUnwrap(CategoryValues("SLEEP_REM"))
    let predicate = try XCTUnwrap(deletePredicate(rem) as? NSCompoundPredicate)
    XCTAssertEqual(predicate.subpredicates.count, 3)
    XCTAssertEqual(predicate.subpredicates.last as? NSPredicate, rem.predicate)
    // The range and owner only for a type with a category type of its own.
    let steps = try XCTUnwrap(deletePredicate(nil) as? NSCompoundPredicate)
    XCTAssertEqual(steps.subpredicates.count, 2)
  }

  func testHealthKitTakesTheQueries() {
    // HealthKit raises an exception (crashing the app) for a predicate it does not take, such as
    // "value IN {...}", when the query is created.
    for dataTypeKey in sleepTypes + headacheTypes {
      let type = plugin.dataTypesDict[dataTypeKey]!
      for predicate in [readPredicate(dataTypeKey), deletePredicate(CategoryValues(dataTypeKey))] {
        _ = HKSampleQuery(
          sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil, resultsHandler: { _, _, _ in }
        )
      }
    }
  }

  func testWritesOfWhatHealthKitRaisesForReplyOnce() throws {
    // HealthKit has no unknown sleep stage, values 0 and 1 for a stand hour, 0 for a heart rate
    // event, and requires metadata for menstrual flow and insulin delivery that writeData lacks.
    let samples: [(String, Double)] = [
      ("SLEEP_UNKNOWN", 0), ("APPLE_STAND_HOUR", 5), ("APPLE_STAND_HOUR", -1),
      ("APPLE_STAND_HOUR", .nan), ("APPLE_STAND_HOUR", .infinity), ("HIGH_HEART_RATE_EVENT", 1),
      ("MENSTRUATION_FLOW", 2), ("INSULIN_DELIVERY", 2),
    ]
    let writes: [(String, Write)] = [
      ("writeData", writer.writeData), ("writeDataUUID", writer.writeDataUUID),
    ]
    for (method, write) in writes {
      for (dataTypeKey, value) in samples {
        let arguments: [String: Any] = [
          "value": value, "dataTypeKey": dataTypeKey, "dataUnitKey": "INTERNATIONAL_UNIT",
          "recordingMethod": 2, "startTime": milliseconds(now), "endTime": milliseconds(now),
        ]
        let sent = try replies(to: write, method: method, arguments: arguments)
        let label = "\(method) \(dataTypeKey) \(value)"
        XCTAssertEqual(sent.count, 1, label)
        XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT", label)
      }
    }
  }

  func testHealthKitTakesEveryValueWritesGive() throws {
    for (dataTypeKey, sampleType) in plugin.dataTypesDict {
      // writeData leaves menstrual flow to writeMenstruationFlow.
      guard let type = sampleType as? HKCategoryType, dataTypeKey != "MENSTRUATION_FLOW" else { continue }
      let accepted = try XCTUnwrap(writer.acceptedValues(of: type), dataTypeKey)
      // HealthKit would raise an exception for a value it does not take, ending the test run.
      _ = samples(type, accepted)
      if dataTypeKey == "SLEEP_UNKNOWN" {
        continue
      }
      // A type that covers one value writes that value, whatever value the call gives.
      let ownValue = CategoryValues.sleepValues[dataTypeKey] ?? CategoryValues.headacheValues[dataTypeKey]
      func written(_ value: Int) throws -> Int {
        try writer.checkCategoryValue(Double(value), of: dataTypeKey, for: type)
      }
      for value in accepted {
        XCTAssertEqual(try written(value), ownValue ?? value, dataTypeKey)
      }
      if ownValue == nil {
        for value in [accepted.lowerBound - 1, accepted.upperBound + 1] {
          XCTAssertEqual(
            pluginErrorMessage(try written(value)), "Value \(Double(value)) cannot be written for \(dataTypeKey)"
          )
        }
      }
    }
  }

  func testBeforeIOS16SleepStagesAreAsleep() throws {
    // iOS 15 has inBed, asleep and awake only.
    let sleep = HKCategoryType(.sleepAnalysis)
    XCTAssertEqual(writer.acceptedValues(of: sleep, sleepStages: false), 0...2)
    let asleep = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    let written = [
      "SLEEP_IN_BED": 0, "SLEEP_ASLEEP": asleep, "SLEEP_AWAKE": 2, "SLEEP_LIGHT": asleep,
      "SLEEP_DEEP": asleep, "SLEEP_REM": asleep,
    ]
    for (dataTypeKey, value) in written {
      let sent = Double(try XCTUnwrap(CategoryValues.sleepValues[dataTypeKey]))
      let checked = try writer.checkCategoryValue(sent, of: dataTypeKey, for: sleep, sleepStages: false)
      XCTAssertEqual(checked, value, dataTypeKey)
    }
  }

  /// A sample of [type] at now for each of [values].
  private func samples(_ type: HKCategoryType, _ values: ClosedRange<Int>) -> [HKCategorySample] {
    values.map { HKCategorySample(type: type, value: $0, start: now, end: now) }
  }

  /// The predicate of a read of [dataTypeKey] around now.
  private func readPredicate(_ dataTypeKey: String) -> NSPredicate {
    reader.samplePredicate(from: now - 60, to: now + 60, includeManualEntry: true, dataTypeKey: dataTypeKey)
  }

  /// The predicate of a delete of [values] in the minute before now.
  private func deletePredicate(_ values: CategoryValues?) -> NSPredicate {
    operations.deletePredicate(values, from: now - 60, to: now)
  }
}
