import Flutter
import HealthKit
import XCTest

@testable import health

/// A swim's map has its pool length and laps (HealthDataReader+Swimming.swift), as the Dart
/// SwimmingDetails parses them: the lap length in meters and the lap events with their stroke style.
class SwimmingReadTests: XCTestCase {
  private let reader = HealthDataReader(
    healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
  )
  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: ["SWIMMING_POOL": .swimming]
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testPoolSwimHasItsLapLengthInMetersAndItsLaps() throws {
    let swim = workout(
      .swimming,
      metadata: [
        HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue,
        HKMetadataKeyLapLength: HKQuantity(unit: .yard(), doubleValue: 25),
      ],
      events: [
        lap(1, 2, .backstroke), lap(0, 1, .freestyle),
        HKWorkoutEvent(type: .segment, dateInterval: DateInterval(start: start, duration: 180), metadata: nil),
        lap(2, 3, nil), lap(3, 3, .butterfly),
      ]
    )
    let swimming = try XCTUnwrap(reader.workoutDetails(of: swim)["swimming"] as? [String: Any])

    XCTAssertEqual(try XCTUnwrap(swimming["poolLength"] as? Double), 22.86, accuracy: 1e-9)
    // By their start and without the segment; a lap without a stroke style is unknown, and the
    // laps Apple Watch recorded before watchOS 4 end when they start.
    let laps = try XCTUnwrap(swimming["laps"] as? [[String: Any]])
    XCTAssertEqual(laps.map { $0["strokeStyle"] as? String }, ["freestyle", "backstroke", "unknown", "butterfly"])
    XCTAssertEqual(laps.compactMap { $0["startTime"] as? Int }, [0, 1, 2, 3].map(millisecondsAfterStart))
    XCTAssertEqual(laps.compactMap { $0["endTime"] as? Int }, [1, 2, 3, 3].map(millisecondsAfterStart))
  }

  func testOpenWaterSwimHasLapsWithoutPoolLength() throws {
    let swim = workout(
      .swimming, metadata: [HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.openWater.rawValue],
      events: [lap(0, 10, .freestyle)]
    )
    // As the method channel gets it: NSNull is null on the Dart side.
    let swimming = try XCTUnwrap((reader.workoutDetails(of: swim) as NSDictionary)["swimming"] as? NSDictionary)
    XCTAssertTrue(swimming["poolLength"] is NSNull)
    XCTAssertEqual((swimming["laps"] as? [Any])?.count, 1)
  }

  func testOnlySwimsWithAPoolLengthOrLapsHaveSwimmingDetails() {
    let swimWithoutLaps = workout(
      .swimming, metadata: [HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.openWater.rawValue]
    )
    let runWithLaps = workout(.running, events: [lap(0, 10, .freestyle)])
    for workout in [swimWithoutLaps, runWithLaps] {
      XCTAssertTrue((reader.workoutDetails(of: workout) as NSDictionary)["swimming"] is NSNull)
    }
  }

  func testEveryStrokeStyleHasAName() throws {
    let styles: [HKSwimmingStrokeStyle] = [.unknown, .mixed, .freestyle, .backstroke, .breaststroke, .butterfly]
    XCTAssertEqual(
      styles.map(SwimmingStrokeStyles.name),
      ["unknown", "mixed", "freestyle", "backstroke", "breaststroke", "butterfly"]
    )
    if #available(iOS 16.0, *) {
      XCTAssertEqual(SwimmingStrokeStyles.name(of: .kickboard), "kickboard")
    }
    // A style HealthKit adds later.
    XCTAssertEqual(SwimmingStrokeStyles.name(of: try XCTUnwrap(HKSwimmingStrokeStyle(rawValue: 99))), "unknown")
  }

  func testWrittenSwimReadsBack() throws {
    let styles = ["freestyle", "kickboard", "other", "butterfly"]
    func laps(_ styles: [String]) -> [[String: Any]] {
      styles.indices.map {
        [
          "startTime": millisecondsAfterStart($0), "endTime": millisecondsAfterStart($0 + 1),
          "strokeStyle": styles[$0],
        ]
      }
    }
    let swimming: [String: Any] = ["poolLength": 25.0, "laps": laps(styles)]
    var sent = [Any?]()
    let call = FlutterMethodCall(
      methodName: "writeWorkoutData",
      arguments: [
        "activityType": "SWIMMING_POOL", "startTime": millisecondsAfterStart(0),
        "endTime": millisecondsAfterStart(30), "swimming": swimming, "totalSwimmingStrokeCount": 96,
      ]
    )
    let swim = try XCTUnwrap(try writer.workout(from: call) { sent.append($0) })
    XCTAssertTrue(sent.isEmpty)

    // HealthKit has no style for other, nor kickboard before iOS 16: the iOS version, not
    // SwimmingStrokeStyles, says what a kickboard lap reads back as.
    var kickboard = "unknown"
    if #available(iOS 16.0, *) {
      kickboard = "kickboard"
    }
    let readStyles = ["freestyle", kickboard, "unknown", "butterfly"]
    XCTAssertEqual(
      reader.workoutDetails(of: swim)["swimming"] as? NSDictionary,
      ["poolLength": 25.0, "laps": laps(readStyles)] as NSDictionary
    )
    XCTAssertEqual(reader.workoutActivityName(of: swim), "SWIMMING_POOL")
    XCTAssertEqual(HealthDataReader.totalSwimmingStrokeCount(of: swim), 96)
  }

  /// A half-hour workout of [type] from start, built without saving it.
  private func workout(
    _ type: HKWorkoutActivityType, metadata: [String: Any]? = nil, events: [HKWorkoutEvent]? = nil
  ) -> HKWorkout {
    HKWorkout(
      activityType: type, start: start, end: start + 30 * 60, workoutEvents: events, totalEnergyBurned: nil,
      totalDistance: nil, metadata: metadata
    )
  }

  /// A lap from minute [from] to minute [to] of the workout, with the stroke style [style].
  private func lap(_ from: Double, _ to: Double, _ style: HKSwimmingStrokeStyle?) -> HKWorkoutEvent {
    HKWorkoutEvent(
      type: .lap, dateInterval: DateInterval(start: start + from * 60, end: start + to * 60),
      metadata: style.map { [HKMetadataKeySwimmingStrokeStyle: $0.rawValue] }
    )
  }

  /// The time [minutes] after start, in milliseconds since the epoch.
  private func millisecondsAfterStart(_ minutes: Int) -> Int {
    milliseconds(start + Double(minutes) * 60)
  }
}
