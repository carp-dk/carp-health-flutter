import HealthKit

extension HealthDataReader {
    /// The single point a characteristic type (BIRTH_DATE, GENDER, BLOOD_TYPE) reads as, or nil
    /// for any other type. Characteristics are not samples: the window only sets the point's dates.
    func characteristicDictionary(_ dataTypeKey: String, from dateFrom: Date, to dateTo: Date) -> NSDictionary? {
        let value: Any?
        switch dataTypeKey {
        case HealthConstants.BIRTH_DATE:
            value = getBirthDate()?.timeIntervalSince1970
        case HealthConstants.GENDER:
            value = getGender()?.rawValue
        case HealthConstants.BLOOD_TYPE:
            value = getBloodType()?.rawValue
        default:
            return nil
        }
        return [
            "value": value ?? NSNull(),
            "date_from": Int(dateFrom.timeIntervalSince1970 * 1000),
            "date_to": Int(dateTo.timeIntervalSince1970 * 1000),
            "source_id": "com.apple.Health",
            "source_name": "Health",
            "recording_method": HealthConstants.RecordingMethod.manual.rawValue,
        ]
    }

    /// Gets birth date from HealthKit
    /// - Returns: Birth date
    private func getBirthDate() -> Date? {
        var dob: Date?
        do {
            dob = try healthStore.dateOfBirthComponents().date
        } catch {
            dob = nil
            print("Error retrieving date of birth: \(error)")
        }
        return dob
    }

    /// Gets gender from HealthKit
    /// - Returns: Biological sex
    private func getGender() -> HKBiologicalSex? {
        var bioSex: HKBiologicalSex?
        do {
            bioSex = try healthStore.biologicalSex().biologicalSex
        } catch {
            bioSex = nil
            print("Error retrieving biologicalSex: \(error)")
        }
        return bioSex
    }

    /// Gets blood type from HealthKit
    /// - Returns: Blood type
    private func getBloodType() -> HKBloodType? {
        var bloodType: HKBloodType?
        do {
            bloodType = try healthStore.bloodType().bloodType
        } catch {
            bloodType = nil
            print("Error retrieving blood type: \(error)")
        }
        return bloodType
    }
}
