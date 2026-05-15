import HealthKit

/// Utilities class containing helper methods for data manipulation
class HealthUtilities {
    /// Resolve a best-effort device identifier for a workout's *recording* device.
    ///
    /// HealthKit exposes device information from several places, and which one
    /// is populated depends on which app wrote the workout:
    ///
    /// 1. `sourceRevision.productType` is the Apple hardware identifier of the
    ///    device running the source app (e.g. `"Watch6,1"`, `"iPhone14,2"`).
    ///    For Apple-native workouts this correctly distinguishes Apple Watch
    ///    from iPhone. For third-party apps (Garmin, Strava, etc.) it is
    ///    always the iPhone model running the companion app, which is not the
    ///    actual recording device.
    /// 2. `HKSample.device.name` is set by the writing app and describes the
    ///    actual recording hardware. Third-party apps frequently populate this
    ///    with the friendly device name (e.g. `"Garmin fēnix 7"`).
    /// 3. `HKMetadataKeyDeviceName` is a standard metadata key that some apps
    ///    use instead of `HKSample.device`.
    ///
    /// Strategy: prefer `productType` for Apple-native workouts; for everything
    /// else fall back to the device name reported by the writing app, then to
    /// metadata, and finally to `productType` as a last resort.
    static func resolveWorkoutDeviceModel(_ workout: HKWorkout) -> String? {
        let bundleId = workout.sourceRevision.source.bundleIdentifier.lowercased()
        let isAppleSource = bundleId.hasPrefix("com.apple.")

        if isAppleSource, let productType = workout.sourceRevision.productType {
            return productType
        }

        if let deviceName = workout.device?.name, !deviceName.isEmpty {
            return deviceName
        }

        if let metadataDeviceName = workout.metadata?[HKMetadataKeyDeviceName] as? String,
           !metadataDeviceName.isEmpty {
            return metadataDeviceName
        }

        return workout.sourceRevision.productType
    }

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
