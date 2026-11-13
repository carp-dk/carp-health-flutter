import HealthKit
import XCTest

@testable import health

/// The quantity types of HealthPlugin+MoreQuantityTypes.swift: registered for reads and interval
/// reads, and read in the units the Dart side asks for (data_type_units.dart).
class QuantityTypeTests: XCTestCase {
  private let plugin: HealthPlugin = {
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    return plugin
  }()

  /// Each type's HealthKit identifier (without its HKQuantityTypeIdentifier prefix) and the unit
  /// of its values on the Dart side.
  private let types: [String: (identifier: String, unit: String)] = [
    "TIME_IN_DAYLIGHT": ("TimeInDaylight", "MINUTE"),
    "WALKING_DOUBLE_SUPPORT_PERCENTAGE": ("WalkingDoubleSupportPercentage", "PERCENT"),
    "WALKING_STEP_LENGTH": ("WalkingStepLength", "METER"),
    "WALKING_ASYMMETRY_PERCENTAGE": ("WalkingAsymmetryPercentage", "PERCENT"),
    "APPLE_WALKING_STEADINESS": ("AppleWalkingSteadiness", "PERCENT"),
    "STAIR_ASCENT_SPEED": ("StairAscentSpeed", "METER_PER_SECOND"),
    "STAIR_DESCENT_SPEED": ("StairDescentSpeed", "METER_PER_SECOND"),
    "SIX_MINUTE_WALK_TEST_DISTANCE": ("SixMinuteWalkTestDistance", "METER"),
    "RUNNING_POWER": ("RunningPower", "WATT"),
    "RUNNING_SPEED": ("RunningSpeed", "METER_PER_SECOND"),
    "RUNNING_STRIDE_LENGTH": ("RunningStrideLength", "METER"),
    "RUNNING_VERTICAL_OSCILLATION": ("RunningVerticalOscillation", "METER"),
    "RUNNING_GROUND_CONTACT_TIME": ("RunningGroundContactTime", "MILLISECOND"),
    "HEART_RATE_RECOVERY_ONE_MINUTE": ("HeartRateRecoveryOneMinute", "BEATS_PER_MINUTE"),
    "PHYSICAL_EFFORT": ("PhysicalEffort", "KILOCALORIE_PER_HOUR_KILOGRAM"),
    "ENVIRONMENTAL_AUDIO_EXPOSURE": ("EnvironmentalAudioExposure", "DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL"),
    "HEADPHONE_AUDIO_EXPOSURE": ("HeadphoneAudioExposure", "DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL"),
    "NUMBER_OF_TIMES_FALLEN": ("NumberOfTimesFallen", "COUNT"),
    "BASAL_BODY_TEMPERATURE": ("BasalBodyTemperature", "DEGREE_CELSIUS"),
    "PEAK_EXPIRATORY_FLOW": ("PeakExpiratoryFlowRate", "LITER_PER_MINUTE"),
    "FORCED_VITAL_CAPACITY": ("ForcedVitalCapacity", "LITER"),
    "INHALER_USAGE": ("InhalerUsage", "COUNT"),
    "BLOOD_ALCOHOL_CONTENT": ("BloodAlcoholContent", "PERCENT"),
    "NUMBER_OF_ALCOHOLIC_BEVERAGES": ("NumberOfAlcoholicBeverages", "COUNT"),
    "PUSH_COUNT": ("PushCount", "COUNT"),
    "SWIMMING_STROKE_COUNT": ("SwimmingStrokeCount", "COUNT"),
    "DISTANCE_WHEELCHAIR": ("DistanceWheelchair", "METER"),
    "DISTANCE_DOWNHILL_SNOW_SPORTS": ("DistanceDownhillSnowSports", "METER"),
    "DISTANCE_CROSS_COUNTRY_SKIING": ("DistanceCrossCountrySkiing", "METER"),
    "DISTANCE_PADDLE_SPORTS": ("DistancePaddleSports", "METER"),
    "DISTANCE_ROWING": ("DistanceRowing", "METER"),
    "DISTANCE_SKATING_SPORTS": ("DistanceSkatingSports", "METER"),
    "CYCLING_SPEED": ("CyclingSpeed", "METER_PER_SECOND"),
    "CYCLING_FUNCTIONAL_THRESHOLD_POWER": ("CyclingFunctionalThresholdPower", "WATT"),
    "CROSS_COUNTRY_SKIING_SPEED": ("CrossCountrySkiingSpeed", "METER_PER_SECOND"),
    "PADDLE_SPORTS_SPEED": ("PaddleSportsSpeed", "METER_PER_SECOND"),
    "ROWING_SPEED": ("RowingSpeed", "METER_PER_SECOND"),
    "ENVIRONMENTAL_SOUND_REDUCTION": ("EnvironmentalSoundReduction", "DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL"),
    "WORKOUT_EFFORT_SCORE": ("WorkoutEffortScore", "APPLE_EFFORT_SCORE"),
    "ESTIMATED_WORKOUT_EFFORT_SCORE": ("EstimatedWorkoutEffortScore", "APPLE_EFFORT_SCORE"),
    "APPLE_SLEEPING_BREATHING_DISTURBANCES": ("AppleSleepingBreathingDisturbances", "COUNT"),
  ]

  /// The first iOS version that has the type, for the types newer than iOS 15, the oldest the
  /// plugin supports. Before that version the plugin does not register the type.
  private let firstIOSVersion: [String: Int] = [
    "RUNNING_POWER": 16, "RUNNING_SPEED": 16, "RUNNING_STRIDE_LENGTH": 16, "RUNNING_VERTICAL_OSCILLATION": 16,
    "RUNNING_GROUND_CONTACT_TIME": 16, "HEART_RATE_RECOVERY_ONE_MINUTE": 16, "ENVIRONMENTAL_SOUND_REDUCTION": 16,
    "TIME_IN_DAYLIGHT": 17, "PHYSICAL_EFFORT": 17, "CYCLING_SPEED": 17, "CYCLING_FUNCTIONAL_THRESHOLD_POWER": 17,
    "DISTANCE_CROSS_COUNTRY_SKIING": 18, "DISTANCE_PADDLE_SPORTS": 18, "DISTANCE_ROWING": 18,
    "DISTANCE_SKATING_SPORTS": 18, "CROSS_COUNTRY_SKIING_SPEED": 18, "PADDLE_SPORTS_SPEED": 18, "ROWING_SPEED": 18,
    "WORKOUT_EFFORT_SCORE": 18, "ESTIMATED_WORKOUT_EFFORT_SCORE": 18, "APPLE_SLEEPING_BREATHING_DISTURBANCES": 18,
  ]

  /// Whether the iOS the tests run on has the type.
  private func isAvailable(_ key: String) -> Bool {
    let version = OperatingSystemVersion(majorVersion: firstIOSVersion[key] ?? 15, minorVersion: 0, patchVersion: 0)
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(version)
  }

  func testEveryTypeIsReadInItsUnit() throws {
    XCTAssertEqual(types.count, 41)
    XCTAssertTrue(Set(firstIOSVersion.keys).isSubset(of: types.keys))
    for (key, expected) in types {
      guard isAvailable(key) else {
        // Not registered on an older iOS, so reads of the type fail with notSupported.
        XCTAssertNil(plugin.dataTypesDict[key], key)
        XCTAssertNil(plugin.dataQuantityTypesDict[key], key)
        continue
      }
      let quantityType = try XCTUnwrap(plugin.dataQuantityTypesDict[key], key)
      XCTAssertEqual(quantityType.identifier, "HKQuantityTypeIdentifier" + expected.identifier, key)
      XCTAssertEqual(plugin.dataTypesDict[key], quantityType, key)
      let unit = try XCTUnwrap(plugin.unitDict[expected.unit], expected.unit)
      // HealthKit raises an exception (crashing the app) for a unit that cannot express the type.
      XCTAssertTrue(quantityType.is(compatibleWith: unit), "\(key) in \(expected.unit)")
    }
  }

  func testIntervalsAreSumsOrAverages() {
    let reader = HealthDataReader(
      healthStore: plugin.healthStore, dataTypesDict: plugin.dataTypesDict,
      dataQuantityTypesDict: plugin.dataQuantityTypesDict, unitDict: plugin.unitDict,
      workoutActivityTypeMap: plugin.workoutActivityTypeMap,
      characteristicsTypesDict: plugin.characteristicsTypesDict
    )
    let sums = ["PUSH_COUNT", "TIME_IN_DAYLIGHT", "NUMBER_OF_TIMES_FALLEN", "DISTANCE_ROWING"]
    let averages = ["RUNNING_SPEED", "ENVIRONMENTAL_AUDIO_EXPOSURE", "WORKOUT_EFFORT_SCORE", "PHYSICAL_EFFORT"]
    for key in sums where isAvailable(key) {
      XCTAssertEqual(reader.statisticsOption(for: key), .cumulativeSum, key)
    }
    for key in averages where isAvailable(key) {
      XCTAssertEqual(reader.statisticsOption(for: key), .discreteAverage, key)
    }
  }

  func testEveryOtherQuantityTypeHasIntervals() {
    // The quantity types getHealthIntervalDataFromTypes documents as without interval data.
    let withoutIntervals: Set = [
      "APPLE_MOVE_TIME", "APPLE_STAND_TIME", "ATRIAL_FIBRILLATION_BURDEN", "EXERCISE_TIME",
      "INSULIN_DELIVERY", "PERIPHERAL_PERFUSION_INDEX", "RESPIRATORY_RATE", "UNDERWATER_DEPTH",
      "WALKING_SPEED", "WATER_TEMPERATURE",
    ]
    for (key, sampleType) in plugin.dataTypesDict where sampleType is HKQuantityType {
      if withoutIntervals.contains(key) {
        XCTAssertNil(plugin.dataQuantityTypesDict[key], key)
      } else {
        XCTAssertEqual(plugin.dataQuantityTypesDict[key], sampleType, key)
      }
    }
  }
}
