import Flutter
import HealthKit
import XCTest

@testable import health

/// The intervals of a quantity type are statistics separated by source: HKStatistics has no
/// sources otherwise. Their value is still that of all sources, the sum or the average the type's
/// aggregation style supports, and their sources, those with samples in the interval, are named as
/// Android names those of its aggregates.
class IntervalStatisticsTests: XCTestCase {
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
  /// Sources of the statistics below.
  private let phone = "com.example.phone"
  private let scale = "com.example.scale"
  private let watch = "com.example.watch"

  func testIntervalQueriesSeparateBySource() throws {
    let reads: [(String, String, HKStatisticsOptions)] = [
      ("HEART_RATE", "BEATS_PER_MINUTE", .discreteAverage), ("STEPS", "COUNT", .cumulativeSum),
    ]
    for (dataTypeKey, unitKey, valueOption) in reads {
      let sent = replies(
        to: reader.getIntervalData, method: "getIntervalData",
        arguments: [
          "dataTypeKey": dataTypeKey, "dataUnitKey": unitKey, "interval": 3600,
          "startTime": t0, "endTime": t0 + 3_600_000,
        ]
      )
      // The reply comes once the query, which the store does not run, has results.
      XCTAssertTrue(sent.isEmpty, dataTypeKey)
      let query = try XCTUnwrap(store.queries.last as? HKStatisticsCollectionQuery, dataTypeKey)
      XCTAssertEqual(query.options, [valueOption, .separateBySource], dataTypeKey)
      XCTAssertEqual(HealthDataReader.valueOption(of: query.options), valueOption, dataTypeKey)
    }
    XCTAssertEqual(store.queries.count, reads.count)
  }

  func testEveryQuantityTypeHasOneValueOption() {
    // An option the aggregation style supports (others raise an exception, crashing the app),
    // and separateBySource, which every style supports.
    let valueOptions: [HKStatisticsOptions] = [.cumulativeSum, .discreteAverage]
    for (dataTypeKey, type) in reader.dataQuantityTypesDict {
      let options = reader.intervalQueryOptions(for: dataTypeKey)
      let valueOption = HealthDataReader.valueOption(of: options)
      XCTAssertTrue(options.contains(.separateBySource), dataTypeKey)
      XCTAssertTrue(valueOptions.contains(valueOption), dataTypeKey)
      XCTAssertEqual(valueOption == .cumulativeSum, type.aggregationStyle == .cumulative, dataTypeKey)
      XCTAssertEqual(valueOption, reader.statisticsOption(for: dataTypeKey), dataTypeKey)
    }
  }

  func testValueOptionLeavesOutSeparateBySourceOnly() {
    XCTAssertEqual(HealthDataReader.valueOption(of: [.discreteMax, .separateBySource]), .discreteMax)
    XCTAssertEqual(HealthDataReader.valueOption(of: [.discreteMin, .separateBySource]), .discreteMin)
    XCTAssertEqual(HealthDataReader.valueOption(of: .cumulativeSum), .cumulativeSum)
    XCTAssertEqual(HealthDataReader.valueOption(of: .separateBySource), [])
  }

  func testIntervalSourcesAreTheirAppsJoined() {
    // Sorted, as HealthKit lists the sources in no particular order, and each once.
    let watch = "com.apple.health.8C2B5C1E-6F1A-4D3B-9E4A-2B7D9C0F1A23"
    let source = HealthDataReader.intervalSource(
      bundleIdentifiers: ["com.example.steps", watch, "com.example.steps"]
    )
    XCTAssertEqual(source, ["source_id": "", "source_name": "\(watch), com.example.steps"])
    XCTAssertEqual(
      HealthDataReader.intervalSource(bundleIdentifiers: ["com.example.steps"]),
      ["source_id": "", "source_name": "com.example.steps"]
    )
    XCTAssertEqual(HealthDataReader.intervalSource(bundleIdentifiers: []), ["source_id": "", "source_name": ""])
  }

  func testIntervalSourcesAreThoseWithSamplesInIt() {
    // HealthKit lists every source of the collection in each interval, also those without samples
    // in it, whose quantity is nil; the sum counts for a sum, the average for an average.
    let statistics = SourceStatistics(
      sources: [watch, phone, scale], sums: [watch: 20, scale: 5], averages: [phone: 60]
    )
    let sums = HealthDataReader.sourcesWithSamples(of: statistics, options: [.cumulativeSum, .separateBySource])
    XCTAssertEqual(sums, [watch, scale])
    let averages = HealthDataReader.sourcesWithSamples(of: statistics, options: [.discreteAverage, .separateBySource])
    XCTAssertEqual(averages, [phone])
  }

  func testIntervalOfOneOfTwoSourcesNamesThatOne() {
    // Heart rate of two apps in the first hour and of the watch only in the second.
    let options = reader.intervalQueryOptions(for: "HEART_RATE")
    let hours = [
      SourceStatistics(sources: [phone, watch], averages: [phone: 60, watch: 100]),
      SourceStatistics(sources: [phone, watch], averages: [watch: 90]),
    ]
    let names = hours.map {
      HealthDataReader.intervalSource(
        bundleIdentifiers: HealthDataReader.sourcesWithSamples(of: $0, options: options)
      )["source_name"]
    }
    XCTAssertEqual(names, ["\(phone), \(watch)", watch])
  }

  func testIntervalWithoutSourcesHasNoSourceName() {
    let options = reader.intervalQueryOptions(for: "STEPS")
    let empty = HealthDataReader.sourcesWithSamples(of: SourceStatistics(sources: [watch]), options: options)
    XCTAssertEqual(empty, [])
    XCTAssertEqual(HealthDataReader.intervalSource(bundleIdentifiers: empty), ["source_id": "", "source_name": ""])
    XCTAssertEqual(HealthDataReader.sourcesWithSamples(of: SourceStatistics(sources: nil), options: options), [])
  }
}

/// The statistics of an interval separated by its [sources], which have the [sums] and the
/// [averages] given (in counts) and no other quantities.
private struct SourceStatistics: SourceSeparatedStatistics {
  let sources: [String]?
  var sums = [String: Double]()
  var averages = [String: Double]()

  func sumQuantity(for source: String) -> HKQuantity? {
    sums[source].map { HKQuantity(unit: .count(), doubleValue: $0) }
  }

  func averageQuantity(for source: String) -> HKQuantity? {
    averages[source].map { HKQuantity(unit: .count(), doubleValue: $0) }
  }

  func minimumQuantity(for _: String) -> HKQuantity? {
    nil
  }

  func maximumQuantity(for _: String) -> HKQuantity? {
    nil
  }
}
