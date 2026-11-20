import Flutter
import HealthKit

extension HealthDataWriter {
    /// Writes insulin delivery data
    /// - Parameters:
    ///   - call: Flutter method call
    ///   - result: Flutter result callback
    func writeInsulinDelivery(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard let arguments = call.arguments as? NSDictionary,
              let units = (arguments["units"] as? Double),
              let reason = (arguments["reason"] as? NSNumber),
              let startTime = (arguments["startTime"] as? NSNumber),
              let endTime = (arguments["endTime"] as? NSNumber)
        else {
            throw PluginError(message: "Invalid Arguments")
        }
        let dateFrom = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        let dateTo = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)

        let type = HKSampleType.quantityType(forIdentifier: .insulinDelivery)!
        guard validateSampleDates(start: dateFrom, end: dateTo, of: [type], result: result) else { return }
        let quantity = HKQuantity(unit: HKUnit.internationalUnit(), doubleValue: units)
        let metadata = [HKMetadataKeyInsulinDeliveryReason: reason]

        let insulin_sample = HKQuantitySample(
            type: type, quantity: quantity, start: dateFrom, end: dateTo, metadata: metadata
        )

        healthStore.save(
            insulin_sample,
            withCompletion: { success, error in
                if let err = error {
                    print("Error Saving Insulin Delivery Sample: \(err.localizedDescription)")
                }
                DispatchQueue.main.async {
                    result(success)
                }
            }
        )
    }
}
