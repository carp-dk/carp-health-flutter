import Flutter
import Foundation
import os

class HKBackgroundDeliveryWorker {
    private struct BackgroundChannel {
        static let name = "flutter_health/background_channel"
        static let initialized = "backgroundChannelInitialized"
        static let syncComplete = "syncComplete"
    }

    private static let log = OSLog(
        subsystem: "co.za.apextechnology.womenscalorietracker",
        category: "HealthKitBGDelivery"
    )

    // iOS gives a background-delivery handler a limited execution budget; fire teardown
    // before it expires if the Dart entrypoint never calls syncComplete.
    private static let watchdogTimeout: TimeInterval = 25

    private var flutterEngine: FlutterEngine?
    private var backgroundChannel: FlutterMethodChannel?
    private var hasFinished = false

    /// Spins up a headless Flutter engine to run the registered Dart callback.
    /// MUST be invoked on the main thread (HKObserverQuery handlers fire off-main).
    func run(completionHandler: @escaping () -> Void) {
        guard let callbackHandle = HKDeliveryUserDefaults.getCallbackHandle(),
              let info = FlutterCallbackCache.lookupCallbackInformation(callbackHandle)
        else {
            os_log("No callback handle registered, skipping background delivery", log: HKBackgroundDeliveryWorker.log, type: .error)
            completionHandler()
            return
        }

        let engine = FlutterEngine(name: "health.bgdelivery", project: nil, allowHeadlessExecution: true)
        flutterEngine = engine

        engine.run(withEntrypoint: info.callbackName, libraryURI: info.callbackLibraryPath)
        HealthPlugin.pluginRegistrantCallback?(engine)

        let channel = FlutterMethodChannel(name: BackgroundChannel.name, binaryMessenger: engine.binaryMessenger)
        backgroundChannel = channel

        // Strong self keeps the worker and its engine alive across the Dart round-trip;
        // clearing backgroundChannel below releases this closure, breaking the cycle.
        channel.setMethodCallHandler { call, result in
            guard call.method == BackgroundChannel.syncComplete else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
            self.finish(completionHandler)
        }

        channel.invokeMethod(BackgroundChannel.initialized, arguments: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + HKBackgroundDeliveryWorker.watchdogTimeout) {
            self.finish(completionHandler)
        }
    }

    /// Tears down the engine and signals completion exactly once, whether triggered by
    /// syncComplete or the watchdog timeout (whichever arrives first wins via hasFinished).
    private func finish(_ completionHandler: @escaping () -> Void) {
        guard !hasFinished else { return }
        hasFinished = true
        flutterEngine?.destroyContext()
        flutterEngine = nil
        backgroundChannel = nil
        completionHandler()
    }
}
