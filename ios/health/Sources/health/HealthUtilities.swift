import Flutter
import HealthKit

/// Utilities class containing helper methods for data manipulation
class HealthUtilities {
    /// Sanitize metadata to make it Flutter-friendly
    /// - Parameter metadata: The metadata dictionary to sanitize
    /// - Returns: A dictionary with sanitized values
    static func sanitizeMetadata(_ metadata: [String: Any]?) -> [String: Any] {
        guard let metadata else { return [:] }

        var sanitized = [String: Any]()

        for (key, value) in metadata {
            switch value {
            case let stringValue as String:
                sanitized[key] = stringValue
            case let numberValue as NSNumber:
                sanitized[key] = numberValue
            case let boolValue as Bool:
                sanitized[key] = boolValue
            case let arrayValue as [Any]:
                sanitized[key] = sanitizeArray(arrayValue)
            case let mapValue as [String: Any]:
                sanitized[key] = sanitizeMetadata(mapValue)
            default:
                continue
            }
        }

        return sanitized
    }

    /// Sanitize an array to make it Flutter-friendly
    /// - Parameter array: The array to sanitize
    /// - Returns: An array with sanitized values
    static func sanitizeArray(_ array: [Any]) -> [Any] {
        var sanitizedArray: [Any] = []

        for value in array {
            switch value {
            case let stringValue as String:
                sanitizedArray.append(stringValue)
            case let numberValue as NSNumber:
                sanitizedArray.append(numberValue)
            case let boolValue as Bool:
                sanitizedArray.append(boolValue)
            case let arrayValue as [Any]:
                sanitizedArray.append(sanitizeArray(arrayValue))
            case let mapValue as [String: Any]:
                sanitizedArray.append(sanitizeMetadata(mapValue))
            default:
                continue
            }
        }

        return sanitizedArray
    }

    /// Convert milliseconds since epoch to Date
    /// - Parameter milliseconds: Milliseconds since epoch
    /// - Returns: Date object
    static func dateFromMilliseconds(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }

    /// Map a HealthKit error to the error codes shared with Android
    /// - Parameters:
    ///   - error: The error reported by HealthKit
    ///   - operation: What failed, for the message
    ///   - fallbackCode: Code for errors that are not classified, including errors outside HKErrorDomain
    /// - Returns: A FlutterError with details {"domain": String, "nativeCode": Int}
    static func flutterError(
        for error: Error, operation: String, fallbackCode: String = "HEALTH_ERROR"
    ) -> FlutterError {
        let nsError = error as NSError
        return FlutterError(
            code: errorCode(for: nsError) ?? fallbackCode,
            message: "Error \(operation): \(nsError.localizedDescription)",
            details: ["domain": nsError.domain, "nativeCode": nsError.code]
        )
    }

    /// Whether [error] is HealthKit's "no data" error. Callers reply an empty success instead of an error.
    static func isNoData(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorNoData.rawValue
    }

    /// The shared code of a classified HealthKit error, nil for any other error.
    private static func errorCode(for error: NSError) -> String? {
        guard error.domain == HKErrorDomain, let code = HKError.Code(rawValue: error.code) else {
            return nil
        }
        if #available(iOS 17.0, *), code == .errorDataSizeExceeded {
            return "DATA_TOO_LARGE"
        }
        if #available(iOS 18.0, *), code == .errorNotPermissibleForGuestUserMode {
            return "PERMISSION_DENIED"
        }
        switch code {
        case .errorAuthorizationDenied, .errorAuthorizationNotDetermined, .errorRequiredAuthorizationDenied,
             .errorHealthDataRestricted:
            return "PERMISSION_DENIED"
        case .errorDatabaseInaccessible:
            // Protected data is unreadable while the device is locked; it reads again once unlocked.
            return "DEVICE_LOCKED"
        case .errorHealthDataUnavailable:
            return "NOT_SUPPORTED"
        case .errorInvalidArgument:
            return "INVALID_ARGUMENT"
        default:
            return nil
        }
    }
}

/// Extension to provide type conversion helpers for HKWorkoutActivityType
extension HKWorkoutActivityType {
    /// Convert HKWorkoutActivityType to string
    /// - Parameter type: The workout activity type
    /// - Returns: String representation of the activity type
    static func toString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .americanFootball: "americanFootball"
        case .archery: "archery"
        case .australianFootball: "australianFootball"
        case .badminton: "badminton"
        case .baseball: "baseball"
        case .basketball: "basketball"
        case .bowling: "bowling"
        case .boxing: "boxing"
        case .climbing: "climbing"
        case .cricket: "cricket"
        case .crossTraining: "crossTraining"
        case .curling: "curling"
        case .cycling: "cycling"
        case .dance: "dance"
        case .danceInspiredTraining: "danceInspiredTraining"
        case .elliptical: "elliptical"
        case .equestrianSports: "equestrianSports"
        case .fencing: "fencing"
        case .fishing: "fishing"
        case .functionalStrengthTraining: "functionalStrengthTraining"
        case .golf: "golf"
        case .gymnastics: "gymnastics"
        case .handball: "handball"
        case .hiking: "hiking"
        case .hockey: "hockey"
        case .hunting: "hunting"
        case .lacrosse: "lacrosse"
        case .martialArts: "martialArts"
        case .mindAndBody: "mindAndBody"
        case .mixedMetabolicCardioTraining: "mixedMetabolicCardioTraining"
        case .paddleSports: "paddleSports"
        case .play: "play"
        case .preparationAndRecovery: "preparationAndRecovery"
        case .racquetball: "racquetball"
        case .rowing: "rowing"
        case .rugby: "rugby"
        case .running: "running"
        case .sailing: "sailing"
        case .skatingSports: "skatingSports"
        case .snowSports: "snowSports"
        case .soccer: "soccer"
        case .softball: "softball"
        case .squash: "squash"
        case .stairClimbing: "stairClimbing"
        case .surfingSports: "surfingSports"
        case .swimming: "swimming"
        case .tableTennis: "tableTennis"
        case .tennis: "tennis"
        case .trackAndField: "trackAndField"
        case .traditionalStrengthTraining: "traditionalStrengthTraining"
        case .volleyball: "volleyball"
        case .walking: "walking"
        case .waterFitness: "waterFitness"
        case .waterPolo: "waterPolo"
        case .waterSports: "waterSports"
        case .wrestling: "wrestling"
        case .yoga: "yoga"
        case .barre: "barre"
        case .coreTraining: "coreTraining"
        case .crossCountrySkiing: "crossCountrySkiing"
        case .downhillSkiing: "downhillSkiing"
        case .flexibility: "flexibility"
        case .highIntensityIntervalTraining: "highIntensityIntervalTraining"
        case .jumpRope: "jumpRope"
        case .kickboxing: "kickboxing"
        case .pilates: "pilates"
        case .snowboarding: "snowboarding"
        case .stairs: "stairs"
        case .stepTraining: "stepTraining"
        case .wheelchairWalkPace: "wheelchairWalkPace"
        case .wheelchairRunPace: "wheelchairRunPace"
        case .taiChi: "taiChi"
        case .mixedCardio: "mixedCardio"
        case .handCycling: "handCycling"
        case .underwaterDiving: "underwaterDiving"
        default: "other"
        }
    }
}
