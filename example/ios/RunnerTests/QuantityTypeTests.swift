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

  func testEveryTypeIsReadInItsUnit() throws {
    // The tests run on iOS 18 or later, which has all of them.
    XCTAssertEqual(types.count, 41)
    for (key, expected) in types {
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
    for key in ["PUSH_COUNT", "TIME_IN_DAYLIGHT", "NUMBER_OF_TIMES_FALLEN", "DISTANCE_ROWING"] {
      XCTAssertEqual(reader.statisticsOption(for: key), .cumulativeSum, key)
    }
    for key in ["RUNNING_SPEED", "ENVIRONMENTAL_AUDIO_EXPOSURE", "WORKOUT_EFFORT_SCORE", "PHYSICAL_EFFORT"] {
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
