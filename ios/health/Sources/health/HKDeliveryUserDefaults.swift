import Foundation

struct HKDeliveryUserDefaults {
    private static let userDefaults = UserDefaults(suiteName: "cachet.plugins.health.delivery")!

    private enum Key {
        static let callbackHandle = "cachet.plugins.health.delivery.callbackHandle"
        static let registeredTypes = "cachet.plugins.health.delivery.registeredTypes"
    }

    static func storeCallbackHandle(_ handle: Int64) {
        userDefaults.setValue(handle, forKey: Key.callbackHandle)
    }

    static func getCallbackHandle() -> Int64? {
        return userDefaults.value(forKey: Key.callbackHandle) as? Int64
    }

    static func storeRegisteredTypes(_ types: [String]) {
        userDefaults.setValue(types, forKey: Key.registeredTypes)
    }

    static func getRegisteredTypes() -> [String] {
        return userDefaults.stringArray(forKey: Key.registeredTypes) ?? []
    }
}
