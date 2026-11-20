import HealthKit
import XCTest

@testable import health

/// What a workout's map has besides its name and totals (HealthDataReader+WorkoutDetails.swift):
/// its duration without pauses, metadata values in the units of the Dart WorkoutHealthValue, and
/// its events.
class WorkoutDetailsTests: XCTestCase {
  private let reader = HealthDataReader(
    healthStore: HKHealthStore(), dataTypesDict: [:], dataQuantityTypesDict: [:], unitDict: [:],
    workoutActivityTypeMap: [:], characteristicsTypesDict: [:]
  )
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testMetadataIsSentInTheUnitsOfTheDartSide() throws {
    let perHourKilogram = HKUnit.kilocalorie().unitDivided(
      by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour())
    )
    let details = reader.workoutDetails(
      of: workout(metadata: [
        HKMetadataKeyAverageMETs: HKQuantity(unit: perHourKilogram, doubleValue: 8.4),
        HKMetadataKeyElevationAscended: HKQuantity(unit: .foot(), doubleValue: 100),
        HKMetadataKeyElevationDescended: HKQuantity(unit: .meter(), doubleValue: 30),
        HKMetadataKeyIndoorWorkout: true,
        HKMetadataKeyWeatherTemperature: HKQuantity(unit: .degreeFahrenheit(), doubleValue: 68),
        HKMetadataKeyWeatherHumidity: HKQuantity(unit: .percent(), doubleValue: 0.64),
        HKMetadataKeyAverageSpeed: HKQuantity(unit: HKUnit(from: "m/s"), doubleValue: 2.9),
        HKMetadataKeyMaximumSpeed: HKQuantity(unit: HKUnit(from: "km/hr"), doubleValue: 18),
      ])
    )

    func value(_ key: String) throws -> Double { try XCTUnwrap(details[key] as? Double, key) }
    XCTAssertEqual(try value("avgMets"), 8.4, accuracy: 1e-9)
    XCTAssertEqual(try value("elevationAscended"), 30.48, accuracy: 1e-9)
    XCTAssertEqual(try value("elevationDescended"), 30, accuracy: 1e-9)
    XCTAssertEqual(details["indoorWorkout"] as? Bool, true)
    XCTAssertEqual(try value("weatherTemperature"), 20, accuracy: 1e-9)
    XCTAssertEqual(try value("weatherHumidity"), 0.64, accuracy: 1e-9)
    XCTAssertEqual(try value("averageSpeed"), 2.9, accuracy: 1e-9)
    XCTAssertEqual(try value("maximumSpeed"), 5, accuracy: 1e-9)
  }

  func testValuesTheWorkoutDoesNotHaveAreNull() {
    // As the method channel gets them: NSNull is null on the Dart side.
    let details = reader.workoutDetails(of: workout(metadata: nil)) as NSDictionary
    for key in [
      "avgMets", "elevationAscended", "elevationDescended", "indoorWorkout", "weatherTemperature",
      "weatherHumidity", "averageSpeed", "maximumSpeed", "workoutEvents", "swimming",
    ] {
      XCTAssertTrue(details[key] is NSNull, key)
    }
    XCTAssertEqual(details["duration"] as? Double, 3600)
  }

  func testAQuantityOfAnotherKindIsLeftOut() {
    // Converting it would raise an exception that crashes the app.
    let metadata: [String: Any] = [HKMetadataKeyElevationAscended: HKQuantity(unit: .second(), doubleValue: 5)]
    XCTAssertNil(HealthDataReader.quantity(metadata, HKMetadataKeyElevationAscended, in: .meter()))
    XCTAssertNil(HealthDataReader.quantity(nil, HKMetadataKeyElevationAscended, in: .meter()))
    XCTAssertNil(HealthDataReader.quantity(["key": "text"], "key", in: .meter()))
  }

  func testEventsHaveTheirTypeStartAndEnd() throws {
    let events = [
      event(.pause, at: 20),
      event(.resume, at: 25),
      HKWorkoutEvent(
        type: .lap, dateInterval: DateInterval(start: start, end: start + 30 * 60), metadata: nil
      ),
    ]
    let details = reader.workoutDetails(of: workout(metadata: nil, events: events))

    // In the order HealthKit keeps them: by their start.
    let sent = try XCTUnwrap(details["workoutEvents"] as? [[String: Any]])
    XCTAssertEqual(sent.map { $0["type"] as? String }, ["lap", "pause", "resume"])
    let startMilliseconds = Int(start.timeIntervalSince1970 * 1000)
    XCTAssertEqual(sent.compactMap { $0["start"] as? Int }, [0, 20, 25].map { startMilliseconds + $0 * 60_000 })
    XCTAssertEqual(sent.compactMap { $0["end"] as? Int }, [30, 20, 25].map { startMilliseconds + $0 * 60_000 })
    // The five minutes of the pause are not part of the duration.
    XCTAssertEqual(details["duration"] as? Double, 55 * 60)
  }

  func testEveryEventTypeHasAName() {
    let types: [HKWorkoutEventType] = [
      .pause, .resume, .lap, .marker, .motionPaused, .motionResumed, .segment, .pauseOrResumeRequest,
    ]
    XCTAssertEqual(
      types.map(HealthDataReader.workoutEventTypeName),
      [
        "pause", "resume", "lap", "marker", "motionPaused", "motionResumed", "segment",
        "pauseOrResumeRequest",
      ]
    )
  }

  /// An hour-long run from start, built without saving it.
  private func workout(metadata: [String: Any]?, events: [HKWorkoutEvent]? = nil) -> HKWorkout {
    HKWorkout(
      activityType: .running, start: start, end: start + 3600, workoutEvents: events,
      totalEnergyBurned: nil, totalDistance: nil, metadata: metadata
    )
  }

  /// An event of type at the given minute of the workout.
  private func event(_ type: HKWorkoutEventType, at minute: Double) -> HKWorkoutEvent {
    HKWorkoutEvent(
      type: type, dateInterval: DateInterval(start: start + minute * 60, duration: 0), metadata: nil
    )
  }
}
