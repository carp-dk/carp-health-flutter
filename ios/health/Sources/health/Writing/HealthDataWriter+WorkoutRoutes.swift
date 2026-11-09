import CoreLocation
import Flutter
import HealthKit

extension HealthDataWriter {
    /// Starts a new workout route builder session.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func startWorkoutRoute(call _: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil
                )
            )
            return
        }

        let identifier = UUID().uuidString
        let builder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        storeWorkoutRouteBuilder(builder, for: identifier)
        result(identifier)
    }

    /// Inserts a batch of workout route locations into an active builder.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func insertWorkoutRouteData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil
                )
            )
            return
        }

        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String,
            let rawLocations = arguments["locations"] as? [NSDictionary]
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId or locations for route insertion",
                    details: nil
                )
            )
            return
        }

        guard let builder = workoutRouteBuilder(for: builderId) else {
            result(
                FlutterError(
                    code: "ROUTE_ERROR",
                    message: "No active workout route builder for identifier \(builderId)",
                    details: nil
                )
            )
            return
        }

        if rawLocations.isEmpty {
            result(true)
            return
        }

        let locations: [CLLocation]
        do {
            locations = try parseLocations(rawLocations)
        } catch {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: error.localizedDescription,
                    details: nil
                )
            )
            return
        }

        builder.insertRouteData(locations) { success, error in
            DispatchQueue.main.async {
                if let error {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Error inserting workout route data: \(error.localizedDescription)",
                            details: nil
                        )
                    )
                } else {
                    result(success)
                }
            }
        }
    }

    /// Completes an active workout route builder and associates it with an existing workout.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func finishWorkoutRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil
                )
            )
            return
        }

        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String,
            let workoutUUIDString = arguments["workoutUUID"] as? String,
            let workoutUUID = UUID(uuidString: workoutUUIDString)
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId or workoutUUID for finishing route",
                    details: nil
                )
            )
            return
        }

        guard let builder = workoutRouteBuilder(for: builderId) else {
            result(
                FlutterError(
                    code: "ROUTE_ERROR",
                    message: "No active workout route builder for identifier \(builderId)",
                    details: nil
                )
            )
            return
        }

        let metadata = arguments["metadata"] as? [String: Any]
        let predicate = HKQuery.predicateForObject(with: workoutUUID)
        let workoutType = HKObjectType.workoutType()

        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { [weak self] _, samplesOrNil, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Error fetching workout for route: \(error.localizedDescription)",
                            details: nil
                        )
                    )
                }
                return
            }

            guard let workout = (samplesOrNil?.first as? HKWorkout) else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "ROUTE_ERROR",
                            message: "Workout with UUID \(workoutUUIDString) not found",
                            details: nil
                        )
                    )
                }
                return
            }

            var finalMetadata = metadata ?? [:]
            finalMetadata["workout_uuid"] = workoutUUIDString

            builder.finishRoute(with: workout, metadata: finalMetadata) {
                [weak self] route, finishError in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.removeWorkoutRouteBuilder(for: builderId)
                    if let finishError {
                        result(
                            FlutterError(
                                code: "ROUTE_ERROR",
                                message:
                                "Error finishing workout route: \(finishError.localizedDescription)",
                                details: nil
                            )
                        )
                    } else if let route {
                        result([
                            "uuid": "\(route.uuid)",
                            "startDate":
                                Int(route.startDate.timeIntervalSince1970 * 1000),
                            "endDate":
                                Int(route.endDate.timeIntervalSince1970 * 1000),
                        ])
                    } else {
                        result(
                            FlutterError(
                                code: "ROUTE_ERROR",
                                message: "Workout route builder returned no route",
                                details: nil
                            )
                        )
                    }
                }
            }
        }

        healthStore.execute(query)
    }

    /// Discards an active workout route builder session.
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func discardWorkoutRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 11.0, *) else {
            result(
                FlutterError(
                    code: "UNSUPPORTED_FEATURE",
                    message: "Workout routes are only available on iOS 11.0 and above.",
                    details: nil
                )
            )
            return
        }

        guard
            let arguments = call.arguments as? NSDictionary,
            let builderId = arguments["builderId"] as? String
        else {
            result(
                FlutterError(
                    code: "ARGUMENT_ERROR",
                    message: "Missing builderId for discarding workout route",
                    details: nil
                )
            )
            return
        }

        guard let builder = removeWorkoutRouteBuilder(for: builderId) else {
            result(false)
            return
        }

        builder.discard()
        result(true)
    }
}
