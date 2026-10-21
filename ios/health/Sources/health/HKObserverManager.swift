import Foundation
import HealthKit
import os
import UIKit

class HKObserverManager {
    static let shared = HKObserverManager()

    private static let log = OSLog(
        subsystem: "co.za.apextechnology.womenscalorietracker",
        category: "HealthKitBGDelivery"
    )

    private var activeQueries: [HKObserverQuery] = []
    // One worker at a time. HealthKit delivers a single wake to every observer that has new
    // data, so a per-callback worker spawns one headless FlutterEngine per registered type.
    // The worker is retained until its engine signals syncComplete; without this the temporary
    // worker is deallocated when run() returns, tearing down the engine mid-sync.
    private var activeWorker: HKBackgroundDeliveryWorker?
    private var pendingCompletions: [HKObserverQueryCompletionHandler] = []
    private weak var healthStore: HKHealthStore?

    private init() {}

    func configure(healthStore: HKHealthStore, typeNames: [String], dataTypesDict: [String: HKSampleType]) {
        self.healthStore = healthStore

        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()

        // Background delivery is registered against HealthKit, not against the query, and
        // outlives both the process and an app upgrade. A type dropped from typeNames would
        // keep waking the app with no observer to call its completion handler, which HealthKit
        // reads as a failed delivery and retries. Clear the registration, then re-enable the
        // current set from the completion so the two do not race.
        healthStore.disableAllBackgroundDelivery { _, error in
            if let error = error {
                os_log("disableAllBackgroundDelivery failed: %{public}@", log: HKObserverManager.log, type: .error, error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.registerObservers(healthStore: healthStore, typeNames: typeNames, dataTypesDict: dataTypesDict)
            }
        }
    }

    private func registerObservers(healthStore: HKHealthStore, typeNames: [String], dataTypesDict: [String: HKSampleType]) {
        for typeName in typeNames {
            guard let sampleType = dataTypesDict[typeName] else {
                os_log("Unknown type %{public}@ requested for background delivery, skipping", log: HKObserverManager.log, type: .info, typeName)
                continue
            }
            guard isBackgroundDeliverySupported(sampleType) else {
                os_log("Type %{public}@ does not support background delivery, skipping", log: HKObserverManager.log, type: .info, typeName)
                continue
            }
            registerObserver(healthStore: healthStore, sampleType: sampleType, typeName: typeName)
        }
    }

    func reRegisterFromStored(healthStore: HKHealthStore, dataTypesDict: [String: HKSampleType]) {
        // A background-delivery engine runs the host app's plugin registrant, which re-enters
        // HealthPlugin.register(with:). Re-arming from there would stop and re-execute the
        // live queries from inside the observer callback that is currently delivering, and
        // -[HKQuery deactivate] barrier-syncs onto that same queue and deadlocks. Observers
        // already exist in that case, so there is nothing to re-arm.
        guard activeQueries.isEmpty else { return }
        let storedTypes = HKDeliveryUserDefaults.getRegisteredTypes()
        guard !storedTypes.isEmpty else { return }
        configure(healthStore: healthStore, typeNames: storedTypes, dataTypesDict: dataTypesDict)
    }

    // HealthKit supports background delivery for HKWorkoutType (a regular HKSample),
    // so a finished workout can wake the app. Only series types (HKWorkoutRoute),
    // audiograms and ECGs are genuinely unsupported.
    private func isBackgroundDeliverySupported(_ sampleType: HKSampleType) -> Bool {
        if sampleType is HKAudiogramSampleType { return false }
        if sampleType is HKSeriesType { return false }
        if #available(iOS 14.0, *), sampleType is HKElectrocardiogramType { return false }
        return true
    }

    private func registerObserver(healthStore: HKHealthStore, sampleType: HKSampleType, typeName: String) {
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
            if let error = error {
                os_log("enableBackgroundDelivery failed for %{public}@: %{public}@", log: HKObserverManager.log, type: .error, typeName, error.localizedDescription)
            } else {
                os_log("enableBackgroundDelivery succeeded for %{public}@: %{public}@", log: HKObserverManager.log, type: .info, typeName, success ? "true" : "false")
            }
        }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, hkCompletion, error in
            if let error = error {
                os_log("Observer query error for %{public}@: %{public}@", log: HKObserverManager.log, type: .error, typeName, error.localizedDescription)
                hkCompletion()
                return
            }
            DispatchQueue.main.async {
                // HKObserverQuery fires in the foreground too; spinning a headless FlutterEngine
                // while the live app is running re-runs plugin/Firebase init and crashes. The
                // foreground app already syncs via its normal in-app path, so only the background
                // case needs the headless engine.
                guard UIApplication.shared.applicationState == .background else {
                    hkCompletion()
                    return
                }
                HKObserverManager.shared.runBackgroundSync(completion: hkCompletion)
            }
        }

        healthStore.execute(query)
        activeQueries.append(query)
    }

    /// Runs the Dart sync callback on a single headless engine per wake, main thread only.
    /// Every observer that fired for this wake has its HealthKit completion held here and
    /// called when that one sync finishes, so a wake costs one engine rather than one per type.
    private func runBackgroundSync(completion: @escaping HKObserverQueryCompletionHandler) {
        pendingCompletions.append(completion)
        guard activeWorker == nil else { return }

        let worker = HKBackgroundDeliveryWorker()
        activeWorker = worker
        worker.run {
            let completions = HKObserverManager.shared.pendingCompletions
            HKObserverManager.shared.pendingCompletions = []
            HKObserverManager.shared.activeWorker = nil
            for hkCompletion in completions { hkCompletion() }
        }
    }
}
