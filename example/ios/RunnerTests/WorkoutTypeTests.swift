import Flutter
import HealthKit
import XCTest

@testable import health

/// The workout activity type each name writes, as the plugin registers them.
private let typesByName: [String: HKWorkoutActivityType] = {
  let plugin = HealthPlugin()
  plugin.initializeTypes()
  return plugin.workoutActivityTypeMap
}()

/// Several names write the same HealthKit workout type, e.g. SWIMMING, SWIMMING_POOL and
/// SWIMMING_OPEN_WATER write swimming. Reads give one name per type, the same at every launch,
/// refined by the metadata that writes of the specific names add.
class WorkoutTypeTests: XCTestCase {
  private let names = WorkoutActivityNames(typesByName)
  private let reader = HealthDataReader(
    healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: typesByName, characteristicsTypesDict: [:]
  )
  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: typesByName
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testTypesWithSeveralNamesReadAsTheGeneralName() {
    XCTAssertEqual(names.name(of: .running, metadata: nil), "RUNNING")
    XCTAssertEqual(names.name(of: .climbing, metadata: nil), "CLIMBING")
    XCTAssertEqual(names.name(of: .swimming, metadata: nil), "SWIMMING")
  }

  func testOnlyTheGeneralNamesShareTheirType() {
    let namesByType = Dictionary(grouping: typesByName.keys) { typesByName[$0]! }
    let shared = namesByType.filter { $0.value.count > 1 }.keys
    XCTAssertEqual(Set(shared), Set(WorkoutActivityNames.generalNames.keys))
    for (type, name) in WorkoutActivityNames.generalNames {
      XCTAssertEqual(typesByName[name], type, name)
    }
  }

  func testEveryTypeReadsAsANameThatWritesIt() {
    for (name, type) in typesByName {
      let readName = names.name(of: type, metadata: nil)
      XCTAssertEqual(readName.flatMap { typesByName[$0] }, type, name)
    }
    // A type added to HealthKit later has no name yet.
    XCTAssertNil(names.name(of: HKWorkoutActivityType(rawValue: 9999)!, metadata: nil))
  }

  func testWrittenNamesReadBack() throws {
    // HealthKit has no metadata for rock climbing and takes a pool swim only with a lap length.
    let readNames = ["ROCK_CLIMBING": "CLIMBING", "SWIMMING_POOL": "SWIMMING"]
    for name in typesByName.keys {
      let workout = try XCTUnwrap(workout(name), name)
      XCTAssertEqual(workout.workoutActivityType, typesByName[name], name)
      // The name the reader puts in the workout's map, as getHealthDataFromTypes gives it.
      XCTAssertEqual(reader.workoutActivityName(of: workout), readNames[name] ?? name, name)
    }
  }

  func testCallerMetadataWins() throws {
    let workout = try XCTUnwrap(workout("RUNNING_TREADMILL", metadata: ["indoorWorkout": false]))
    XCTAssertEqual(workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool, false)
    XCTAssertEqual(reader.workoutActivityName(of: workout), "RUNNING")
  }

  func testMetadataRefinesTheName() {
    func location(_ location: HKWorkoutSwimmingLocationType) -> [String: Any] {
      [HKMetadataKeySwimmingLocationType: NSNumber(value: location.rawValue)]
    }
    XCTAssertEqual(names.name(of: .swimming, metadata: location(.pool)), "SWIMMING_POOL")
    XCTAssertEqual(names.name(of: .swimming, metadata: location(.openWater)), "SWIMMING_OPEN_WATER")
    XCTAssertEqual(names.name(of: .swimming, metadata: location(.unknown)), "SWIMMING")
    let indoor = [HKMetadataKeyIndoorWorkout: NSNumber(value: true)]
    let outdoor = [HKMetadataKeyIndoorWorkout: NSNumber(value: false)]
    XCTAssertEqual(names.name(of: .running, metadata: indoor), "RUNNING_TREADMILL")
    XCTAssertEqual(names.name(of: .running, metadata: outdoor), "RUNNING")
    // The metadata only refines the type it is about.
    XCTAssertEqual(names.name(of: .walking, metadata: indoor), "WALKING")
    XCTAssertEqual(names.name(of: .running, metadata: location(.pool)), "RUNNING")
  }

  /// The workout writeWorkoutData would save for [name], without saving it.
  private func workout(_ name: String, metadata: [String: Any]? = nil) throws -> HKWorkout? {
    var arguments: [String: Any] = [
      "activityType": name, "startTime": milliseconds(start),
      "endTime": milliseconds(start + 30 * 60),
    ]
    arguments["metadata"] = metadata
    var sent = [Any?]()
    let call = FlutterMethodCall(methodName: "writeWorkoutData", arguments: arguments)
    let workout = try writer.workout(from: call) { sent.append($0) }
    XCTAssertTrue(sent.isEmpty, name)
    return workout
  }
}
