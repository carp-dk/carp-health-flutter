import Flutter
import HealthKit

extension HealthDataOperations {
    /// Check if we have required permissions
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func hasPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        let arguments = call.arguments as? NSDictionary
        guard var types = arguments?["types"] as? [String],
              var permissions = arguments?["permissions"] as? [Int],
              types.count == permissions.count
        else {
            throw PluginError(message: "Invalid Arguments!")
        }

        if let nutritionIndex = types.firstIndex(of: HealthConstants.NUTRITION) {
            types.remove(at: nutritionIndex)
            let nutritionPermission = permissions[nutritionIndex]
            permissions.remove(at: nutritionIndex)

            for nutritionType in nutritionList {
                types.append(nutritionType)
                permissions.append(nutritionPermission)
            }
        }

        for (index, type) in types.enumerated() {
            guard let sampleType = dataTypesDict[type] else {
                print("Warning: Health data type '\(type)' not found in dataTypesDict")
                result(false)
                return
            }

            let success = hasPermission(type: sampleType, access: permissions[index])
            if success == nil || success == false {
                result(success)
                return
            }
            if let characteristicType = characteristicsTypesDict[type] {
                let characteristicSuccess = hasPermission(
                    type: characteristicType, access: permissions[index]
                )
                if characteristicSuccess == nil || characteristicSuccess == false {
                    result(characteristicSuccess)
                    return
                }
            }
        }

        result(true)
    }

    /// Request authorization for health data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func requestAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let types = arguments["types"] as? [String],
              let permissions = arguments["permissions"] as? [Int],
              permissions.count == types.count
        else {
            throw PluginError(message: "Invalid Arguments!")
        }

        var typesToRead = Set<HKObjectType>()
        var typesToWrite = Set<HKSampleType>()

        for (index, key) in types.enumerated() {
            if key == HealthConstants.NUTRITION {
                for nutritionType in nutritionList {
                    guard let nutritionData = dataTypesDict[nutritionType] else {
                        print(
                            "Warning: Nutrition data type '\(nutritionType)' not found in dataTypesDict"
                        )
                        continue
                    }
                    let access = permissions[index]
                    switch access {
                    case 0:
                        typesToRead.insert(nutritionData)
                    case 1:
                        typesToWrite.insert(nutritionData)
                    default:
                        typesToRead.insert(nutritionData)
                        typesToWrite.insert(nutritionData)
                    }
                }
            } else {
                let access = permissions[index]

                if let dataType = dataTypesDict[key] {
                    switch access {
                    case 0:
                        typesToRead.insert(dataType)
                    case 1:
                        typesToWrite.insert(dataType)
                    default:
                        typesToRead.insert(dataType)
                        typesToWrite.insert(dataType)
                    }
                }

                if let characteristicsType = characteristicsTypesDict[key] {
                    switch access {
                    case 0:
                        typesToRead.insert(characteristicsType)
                    case 1:
                        throw PluginError(
                            message:
                            "Cannot request write permission for characteristic type \(characteristicsType)"
                        )
                    default:
                        typesToRead.insert(characteristicsType)
                    }
                }

                if dataTypesDict[key] == nil, characteristicsTypesDict[key] == nil {
                    print(
                        "Warning: Health data type '\(key)' not found in dataTypesDict or characteristicsTypesDict"
                    )
                }
            }
        }

        // HealthKit raises an exception (crashing the app) for a request without types, e.g. when every
        // requested type is newer than this iOS version, like POWER before iOS 17. No sheet is shown.
        if typesToRead.isEmpty, typesToWrite.isEmpty {
            result(false)
            return
        }

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) {
            success, _ in
            DispatchQueue.main.async {
                result(success)
            }
        }
    }

    /// Check if we have permission for a specific type
    /// - Parameters:
    ///   - type: The object type to check
    ///   - access: Access level (0: read, 1: write, other: read/write)
    /// - Returns: Bool or nil depending on permission status
    private func hasPermission(type: HKObjectType, access: Int) -> Bool? {
        if #available(iOS 13.0, *) {
            let status = healthStore.authorizationStatus(for: type)
            switch access {
            case 0: // READ
                return nil
            case 1: // WRITE
                return status == HKAuthorizationStatus.sharingAuthorized
            default: // READ_WRITE
                return nil
            }
        } else {
            return nil
        }
    }
}
