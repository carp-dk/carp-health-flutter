import CoreLocation

extension HealthDataWriter {
    /// Converts the location maps of an insertWorkoutRouteData call into CLLocations.
    /// Throws when an entry lacks a valid latitude, longitude or timestamp.
    func parseLocations(_ rawLocations: [NSDictionary]) throws -> [CLLocation] {
        try rawLocations.map { entry in
            guard
                let latitudeValue = doubleValue(from: entry["latitude"]),
                let longitudeValue = doubleValue(from: entry["longitude"]),
                let timestampValue = entry["timestamp"]
            else {
                throw PluginError(message: "Invalid workout route location entry")
            }

            let latitude = CLLocationDegrees(latitudeValue)
            let longitude = CLLocationDegrees(longitudeValue)

            guard let timestamp = parseTimestamp(timestampValue) else {
                throw PluginError(message: "Invalid workout route timestamp")
            }

            let altitude = doubleValue(from: entry["altitude"]) ?? 0
            let horizontalAccuracy = doubleValue(from: entry["horizontalAccuracy"])
                ?? kCLLocationAccuracyHundredMeters
            let verticalAccuracy = doubleValue(from: entry["verticalAccuracy"])
                ?? kCLLocationAccuracyHundredMeters
            let speed = doubleValue(from: entry["speed"]) ?? -1
            let course = doubleValue(from: entry["course"]) ?? -1
            let speedAccuracyValue = doubleValue(from: entry["speedAccuracy"])
            let courseAccuracyValue = doubleValue(from: entry["courseAccuracy"])

            if #available(iOS 13.4, *),
               let speedAccuracyValue, let courseAccuracyValue
            {
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    course: course,
                    courseAccuracy: courseAccuracyValue,
                    speed: speed,
                    speedAccuracy: speedAccuracyValue,
                    timestamp: timestamp
                )
            } else {
                return CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    course: course,
                    speed: speed,
                    timestamp: timestamp
                )
            }
        }
    }

    private func parseTimestamp(_ value: Any) -> Date? {
        if let milliseconds = value as? NSNumber {
            return Date(timeIntervalSince1970: milliseconds.doubleValue / 1000.0)
        } else if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue / 1000.0)
        } else if let stringValue = value as? String {
            if let date = isoFormatter.date(from: stringValue) {
                return date
            }
            if let doubleValue = Double(stringValue) {
                return Date(timeIntervalSince1970: doubleValue / 1000.0)
            }
        }
        return nil
    }

    private func doubleValue(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        } else if let doubleValue = value as? Double {
            return doubleValue
        } else if let stringValue = value as? String {
            return Double(stringValue)
        }
        return nil
    }
}
