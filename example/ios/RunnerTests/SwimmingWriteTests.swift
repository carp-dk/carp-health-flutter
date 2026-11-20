import Flutter
import HealthKit
import XCTest

@testable import health

/// A swim's pool length, laps and strokes (HealthDataWriter+Swimming.swift) are saved as Apple
/// Watch saves them: the lap length with the pool location, each lap as a lap event with its stroke
/// style. HealthKit raises an exception (crashing the app) for a lap length without the pool
/// location and for a lap outside the workout, so writes check the swim first and reply one
/// INVALID_ARGUMENT error instead.
class SwimmingWriteTests: XCTestCase {
  private typealias Write = (FlutterMethodCall, @escaping FlutterResult) throws -> Void

  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: ["SWIMMING": .swimming, "SWIMMING_POOL": .swimming, "SWIMMING_OPEN_WATER": .swimming]
  )
  private let reader = HealthDataReader(
    healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)
  private var end: Date { start + 30 * 60 }

  func testPoolLengthIsSavedWithThePoolLocation() throws {
    let swim = try workout("SWIMMING_POOL", ["swimming": ["poolLength": 25.0, "laps": []]])
    XCTAssertEqual(
      swim.metadata?[HKMetadataKeySwimmingLocationType] as? Int, HKWorkoutSwimmingLocationType.pool.rawValue
    )
    let lapLength = try XCTUnwrap(swim.metadata?[HKMetadataKeyLapLength] as? HKQuantity)
    XCTAssertEqual(lapLength.doubleValue(for: .meter()), 25)
    // So it reads as a pool swim again, which a pool swim without a pool length does not.
    XCTAssertEqual(reader.workoutActivityName(of: swim), "SWIMMING_POOL")
    XCTAssertEqual(reader.workoutActivityName(of: try workout("SWIMMING_POOL", [:])), "SWIMMING")
  }

  func testLapsAreLapEventsWithTheirStrokeStyle() throws {
    let styles = ["unknown", "mixed", "freestyle", "backstroke", "breaststroke", "butterfly", "kickboard", "other"]
    let laps = styles.indices.map { lap(Double($0), Double($0 + 1), styles[$0]) }
    let swim = try workout("SWIMMING_POOL", ["swimming": ["poolLength": 50.0, "laps": laps]])

    let events = try XCTUnwrap(swim.workoutEvents)
    XCTAssertEqual(events.map(\.type), Array(repeating: .lap, count: styles.count))
    XCTAssertEqual(events.map(\.dateInterval.start), styles.indices.map { start + Double($0) * 60 })
    XCTAssertEqual(events.map(\.dateInterval.duration), Array(repeating: 60, count: styles.count))
    // HealthKit has no style for other, nor kickboard before iOS 16: the iOS version, not
    // SwimmingStrokeStyles, says what a kickboard lap is saved as.
    var kickboard = 0
    if #available(iOS 16.0, *) {
      kickboard = 6
    }
    XCTAssertEqual(
      events.map { $0.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int }, [0, 1, 2, 3, 4, 5, kickboard, 0]
    )
    // Unlike pauses, laps do not shorten the workout.
    XCTAssertEqual(swim.duration, 30 * 60)
  }

  func testKickboardIsUnknownBeforeIOS16() {
    XCTAssertEqual(SwimmingStrokeStyles.style(named: "kickboard", kickboard: false), .unknown)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(SwimmingStrokeStyles.style(named: "kickboard", kickboard: true), .kickboard)
    }
    XCTAssertEqual(SwimmingStrokeStyles.style(named: "other"), .unknown)
    XCTAssertNil(SwimmingStrokeStyles.style(named: "doggyPaddle"))
  }

  func testStrokeCountIsSavedAsTheWorkoutsTotal() throws {
    let openWater = try workout("SWIMMING_OPEN_WATER", ["totalSwimmingStrokeCount": 640])
    XCTAssertEqual(HealthDataReader.totalSwimmingStrokeCount(of: openWater), 640)
    XCTAssertEqual(
      openWater.metadata?[HKMetadataKeySwimmingLocationType] as? Int,
      HKWorkoutSwimmingLocationType.openWater.rawValue
    )
    let pool = try workout(
      "SWIMMING_POOL", ["swimming": ["poolLength": 25.0, "laps": [lap(0, 1)]], "totalSwimmingStrokeCount": 24]
    )
    XCTAssertEqual(HealthDataReader.totalSwimmingStrokeCount(of: pool), 24)
    XCTAssertEqual(pool.workoutEvents?.count, 1)
  }

  func testNullIsNoSwim() throws {
    // As the Dart side sends what is not set.
    let swim = try workout("SWIMMING_POOL", ["swimming": NSNull(), "totalSwimmingStrokeCount": NSNull()])
    XCTAssertNil(swim.metadata?[HKMetadataKeySwimmingLocationType])
    XCTAssertNil(HealthDataReader.totalSwimmingStrokeCount(of: swim))
    let withoutPoolLength = try workout("SWIMMING_POOL", ["swimming": ["poolLength": NSNull(), "laps": NSNull()]])
    XCTAssertNil(withoutPoolLength.metadata?[HKMetadataKeyLapLength])
    XCTAssertTrue((withoutPoolLength.workoutEvents ?? []).isEmpty)
  }

  func testLapsMaySpanTheWorkoutAndLastNoTime() throws {
    // As the laps Apple Watch recorded before watchOS 4, on a swim of any location.
    let swim = try workout("SWIMMING", ["swimming": ["laps": [lap(0, 30), lap(30, 30, "unknown")]]])
    XCTAssertEqual(swim.workoutEvents?.map(\.dateInterval.duration), [30 * 60, 0])
    XCTAssertNil(swim.metadata?[HKMetadataKeySwimmingLocationType])
  }

  func testSwimsHealthKitDoesNotTakeReplyOnce() throws {
    let length = "poolLength must be more than 0 and at most 1000 meters"
    let within = "A lap must start and end within the workout"
    let shape = "swimming must be a map of poolLength and laps"
    let afterTheEnd: [String: Any] = [
      "startTime": milliseconds(start), "endTime": milliseconds(end) + 1, "strokeStyle": "freestyle",
    ]
    let swims: [(String, Any, String)] = [
      ("SWIMMING_OPEN_WATER", ["poolLength": 25.0], "poolLength can only be given for SWIMMING_POOL"),
      ("SWIMMING", ["poolLength": 25.0], "poolLength can only be given for SWIMMING_POOL"),
      ("SWIMMING_POOL", ["poolLength": 0.0], length),
      ("SWIMMING_POOL", ["poolLength": -25.0], length),
      ("SWIMMING_POOL", ["poolLength": 1000.5], length),
      ("SWIMMING_POOL", ["poolLength": Double.nan], length),
      ("SWIMMING_POOL", ["poolLength": 25.0, "laps": [lap(-1, 1)]], within),
      ("SWIMMING_POOL", ["poolLength": 25.0, "laps": [lap(0, 1), afterTheEnd]], within),
      ("SWIMMING_POOL", ["laps": [lap(2, 1)]], "A lap's startTime must be equal to or earlier than its endTime"),
      ("SWIMMING_POOL", ["laps": [lap(0, 1, "doggyPaddle")]], "doggyPaddle is not a swimming stroke style"),
      (
        "SWIMMING_POOL", ["laps": [["startTime": milliseconds(start), "endTime": milliseconds(end)]]],
        "A lap must be a map of startTime, endTime and strokeStyle"
      ),
      ("SWIMMING_POOL", ["laps": "all"], shape),
      ("SWIMMING_POOL", ["poolLength": "25 m"], shape),
      ("SWIMMING_POOL", "pool", shape),
    ]
    let writes: [(String, Write)] = [
      ("writeWorkoutData", writer.writeWorkoutData), ("writeWorkoutDataUUID", writer.writeWorkoutDataUUID),
    ]
    for (method, write) in writes {
      for (name, swimming, message) in swims {
        // A write that went on would create the workout, which raises an exception and ends the test run.
        let sent = try replies(to: write, method: method, arguments: arguments(name, ["swimming": swimming]))
        XCTAssertEqual(sent.count, 1, message)
        XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT", message)
        XCTAssertEqual((sent.first as? FlutterError)?.message, message)
      }
    }
  }

  /// The arguments of a write of a half-hour workout of [name] from start, with [swim].
  private func arguments(_ name: String, _ swim: [String: Any]) -> [String: Any] {
    swim.merging(["activityType": name, "startTime": milliseconds(start), "endTime": milliseconds(end)]) { $1 }
  }

  /// The workout writeWorkoutData would save for a swim of [name] with [swim], without saving it.
  private func workout(_ name: String, _ swim: [String: Any]) throws -> HKWorkout {
    var sent = [Any?]()
    let call = FlutterMethodCall(methodName: "writeWorkoutData", arguments: arguments(name, swim))
    let workout = try writer.workout(from: call) { sent.append($0) }
    XCTAssertTrue(sent.isEmpty, "\(sent)")
    return try XCTUnwrap(workout)
  }

  /// A lap from minute [from] to minute [to] of the workout, as the Dart side sends it.
  private func lap(_ from: Double, _ to: Double, _ style: String = "freestyle") -> [String: Any] {
    ["startTime": milliseconds(start + from * 60), "endTime": milliseconds(start + to * 60), "strokeStyle": style]
  }
}
