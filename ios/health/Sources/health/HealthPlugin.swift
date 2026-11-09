import Flutter
import HealthKit
import UIKit

/// Main plugin class that coordinates health data operations
public class HealthPlugin: NSObject, FlutterPlugin {
    // Health store and type dictionaries
    let healthStore = HKHealthStore()
    var healthDataTypes = [HKSampleType]()
    var healthDataQuantityTypes = [HKQuantityType]()
    var characteristicsDataTypes = [HKCharacteristicType]()
    var heartRateEventTypes = Set<HKSampleType>()
    var headacheType = Set<HKSampleType>()
    var allDataTypes = Set<HKSampleType>()
    var dataTypesDict: [String: HKSampleType] = [:]
    var dataQuantityTypesDict: [String: HKQuantityType] = [:]
    var unitDict: [String: HKUnit] = [:]
    var workoutActivityTypeMap: [String: HKWorkoutActivityType] = [:]
    var characteristicsTypesDict: [String: HKCharacteristicType] = [:]
    var nutritionList: [String] = []
    private var typesInitialized = false

    /// Service classes
    private lazy var healthDataReader: HealthDataReader = .init(
        healthStore: healthStore,
        dataTypesDict: dataTypesDict,
        dataQuantityTypesDict: dataQuantityTypesDict,
        unitDict: unitDict,
        workoutActivityTypeMap: workoutActivityTypeMap,
        characteristicsTypesDict: characteristicsTypesDict
    )

    private lazy var healthDataWriter: HealthDataWriter = .init(
        healthStore: healthStore,
        dataTypesDict: dataTypesDict,
        unitDict: unitDict,
        workoutActivityTypeMap: workoutActivityTypeMap
    )

    private lazy var healthDataOperations: HealthDataOperations = .init(
        healthStore: healthStore,
        dataTypesDict: dataTypesDict,
        characteristicsTypesDict: characteristicsTypesDict,
        nutritionList: nutritionList
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_health", binaryMessenger: registrar.messenger()
        )
        let instance = HealthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // The readers and writers copy the type dictionaries when first used, so building them
        // again on every call (paged reads make many calls) only costs main-thread time.
        if !typesInitialized {
            initializeTypes()
            typesInitialized = true
        }

        switch call.method {
        case "checkIfHealthDataAvailable":
            healthDataOperations.checkIfHealthDataAvailable(call: call, result: result)

        case "requestAuthorization":
            do {
                try healthDataOperations.requestAuthorization(call: call, result: result)
            } catch {
                result(FlutterError(code: "REQUEST_AUTH_ERROR",
                                    message: "Error requesting authorization: \(error.localizedDescription)",
                                    details: nil))
            }

        case "getData":
            healthDataReader.getData(call: call, result: result)

        case "getDataPage":
            healthDataReader.getDataPage(call: call, result: result)

        case "getDataByUUID":
            healthDataReader.getDataByUUID(call: call, result: result)

        case "getIntervalData":
            healthDataReader.getIntervalData(call: call, result: result)

        case "getTotalStepsInInterval":
            healthDataReader.getTotalStepsInInterval(call: call, result: result)

        case "writeData":
            do {
                try healthDataWriter.writeData(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing data: \(error.localizedDescription)",
                                    details: nil))
            }

        case "writeDataUUID":
            do {
                try healthDataWriter.writeDataUUID(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing data: \(error.localizedDescription)",
                                    details: nil))
            }
            
        case "writeAudiogram":
            do {
                try healthDataWriter.writeAudiogram(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing audiogram: \(error.localizedDescription)",
                                    details: nil))
            }

        case "writeBloodPressure":
            do {
                try healthDataWriter.writeBloodPressure(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing blood pressure: \(error.localizedDescription)",
                                    details: nil))
            }

        case "writeMeal":
            do {
                try healthDataWriter.writeMeal(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing meal: \(error.localizedDescription)",
                                    details: nil))
            }

        case "writeInsulinDelivery":
            do {
                try healthDataWriter.writeInsulinDelivery(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing insulin delivery: \(error.localizedDescription)",
                                    details: nil))
            }

        case "writeWorkoutData":
            do {
                try healthDataWriter.writeWorkoutData(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing workout: \(error.localizedDescription)",
                                    details: nil))
            }
            
        case "writeWorkoutDataUUID":
            do {
                try healthDataWriter.writeWorkoutDataUUID(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing workout: \(error.localizedDescription)",
                                    details: nil))
            }
            

        case "startWorkoutRoute":
            healthDataWriter.startWorkoutRoute(call: call, result: result)

        case "insertWorkoutRouteData":
            healthDataWriter.insertWorkoutRouteData(call: call, result: result)

        case "finishWorkoutRoute":
            healthDataWriter.finishWorkoutRoute(call: call, result: result)

        case "discardWorkoutRoute":
            healthDataWriter.discardWorkoutRoute(call: call, result: result)

        case "writeMenstruationFlow":
            do {
                try healthDataWriter.writeMenstruationFlow(call: call, result: result)
            } catch {
                result(FlutterError(code: "WRITE_ERROR",
                                    message: "Error writing menstruation flow: \(error.localizedDescription)",
                                    details: nil))
            }

        case "hasPermissions":
            do {
                try healthDataOperations.hasPermissions(call: call, result: result)
            } catch {
                result(FlutterError(code: "PERMISSION_ERROR",
                                    message: "Error checking permissions: \(error.localizedDescription)",
                                    details: nil))
            }

        case "delete":
            do {
                healthDataOperations.delete(call: call, result: result)
            } catch {
                result(FlutterError(code: "DELETE_ERROR",
                                    message: "Error deleting data: \(error.localizedDescription)",
                                    details: nil))
            }

        case "deleteByUUID":
            do {
                try healthDataOperations.deleteByUUID(call: call, result: result)
            } catch {
                result(FlutterError(code: "DELETE_ERROR",
                                    message: "Error deleting data by UUID: \(error.localizedDescription)",
                                    details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
