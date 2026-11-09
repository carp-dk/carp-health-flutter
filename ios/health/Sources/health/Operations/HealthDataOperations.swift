import Flutter
import HealthKit

/// Class for managing health data permissions and deletion operations
class HealthDataOperations {
    let healthStore: HKHealthStore
    let dataTypesDict: [String: HKSampleType]
    let characteristicsTypesDict: [String: HKCharacteristicType]
    let nutritionList: [String]

    /// - Parameters:
    ///   - healthStore: The HealthKit store
    ///   - dataTypesDict: Dictionary of data types
    ///   - characteristicsTypesDict: Dictionary of characteristic types
    ///   - nutritionList: List of nutrition data types
    init(
        healthStore: HKHealthStore,
        dataTypesDict: [String: HKSampleType],
        characteristicsTypesDict: [String: HKCharacteristicType],
        nutritionList: [String]
    ) {
        self.healthStore = healthStore
        self.dataTypesDict = dataTypesDict
        self.characteristicsTypesDict = characteristicsTypesDict
        self.nutritionList = nutritionList
    }

    /// Check if HealthKit is available on the device
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func checkIfHealthDataAvailable(call _: FlutterMethodCall, result: @escaping FlutterResult) {
        result(HKHealthStore.isHealthDataAvailable())
    }
}
