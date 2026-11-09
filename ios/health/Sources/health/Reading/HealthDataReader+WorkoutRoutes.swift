import CoreLocation
import HealthKit

extension HealthDataReader {
    /// Builds the maps of [routes] in their order, reading each route's locations.
    /// Fails if a location query fails.
    func workoutRouteDictionaries(
        _ routes: [HKWorkoutRoute],
        includeManualEntry: Bool,
        completion: @escaping (Result<[Any], Error>) -> Void
    ) {
        let routes = includeManualEntry ? routes : routes.filter {
            $0.metadata?[HKMetadataKeyWasUserEntered] as? Bool != true
        }
        guard !routes.isEmpty else {
            completion(.success([]))
            return
        }

        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var routeDictionaries = [[String: Any]?](repeating: nil, count: routes.count)
        var capturedError: Error?

        for (index, route) in routes.enumerated() {
            dispatchGroup.enter()
            var collectedLocations: [CLLocation] = []
            var finished = false

            // HealthKit calls the handler once per batch of locations, one call after another.
            let routeQuery = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
                guard !finished else { return }
                if let locations = locationsOrNil {
                    collectedLocations.append(contentsOf: locations)
                }
                if let error, !HealthUtilities.isNoData(error) {
                    finished = true
                    lock.lock()
                    if capturedError == nil {
                        capturedError = error
                    }
                    lock.unlock()
                    dispatchGroup.leave()
                    return
                }
                guard done || error != nil else { return }
                finished = true
                let dictionary = self.buildWorkoutRouteDictionary(route: route, locations: collectedLocations)
                lock.lock()
                routeDictionaries[index] = dictionary
                lock.unlock()
                dispatchGroup.leave()
            }

            healthStore.execute(routeQuery)
        }

        // Reply from a background queue: encoding a large reply on main would stall the UI.
        dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
            if let error = capturedError {
                completion(.failure(error))
            } else {
                completion(.success(routeDictionaries.compactMap { $0 }))
            }
        }
    }

    private func buildWorkoutRouteDictionary(
        route: HKWorkoutRoute,
        locations: [CLLocation]
    ) -> [String: Any] {
        let routePoints: [[String: Any]] = locations.map { location in
            var entry: [String: Any?] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000),
            ]

            if location.horizontalAccuracy >= 0 {
                entry["horizontalAccuracy"] = location.horizontalAccuracy
            }
            if location.verticalAccuracy >= 0 {
                entry["verticalAccuracy"] = location.verticalAccuracy
                entry["altitude"] = location.altitude
            }
            if location.speed >= 0 {
                entry["speed"] = location.speed
            }
            if #available(iOS 13.4, *) {
                if location.speedAccuracy >= 0 {
                    entry["speedAccuracy"] = location.speedAccuracy
                }
            }
            if location.course >= 0, location.course <= 360 {
                entry["course"] = location.course
            }
            if #available(iOS 13.4, *) {
                if location.courseAccuracy >= 0 {
                    entry["courseAccuracy"] = location.courseAccuracy
                }
            }

            return entry.compactMapValues { $0 }
        }

        let startTimestamp = routePoints.first?["timestamp"] as? Int
            ?? Int(route.startDate.timeIntervalSince1970 * 1000)
        let endTimestamp = routePoints.last?["timestamp"] as? Int
            ?? Int(route.endDate.timeIntervalSince1970 * 1000)

        var metadata = HealthUtilities.sanitizeMetadata(route.metadata)
        metadata["route_point_count"] = routePoints.count

        var dictionary: [String: Any] = [
            "uuid": "\(route.uuid)",
            "route": routePoints,
            "date_from": startTimestamp,
            "date_to": endTimestamp,
            "source_id": route.sourceRevision.source.bundleIdentifier,
            "source_name": route.sourceRevision.source.name,
            "recording_method":
                (route.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
                ? HealthConstants.RecordingMethod.manual.rawValue
                : HealthConstants.RecordingMethod.automatic.rawValue,
            "metadata": metadata,
        ]

        if let workoutUUID = metadata["workout_uuid"] as? String {
            dictionary["workout_uuid"] = workoutUUID
        }

        return dictionary
    }
}
