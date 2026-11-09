import Foundation

/// Page token of getDataPage: "v1:" and the 16 hex digits of the bit pattern of the page
/// boundary's timeIntervalSinceReferenceDate. That double is HealthKit's own representation of
/// a date, so the boundary round-trips exactly. Opaque to Dart, and only valid for the
/// arguments of the call that returned it.
enum DataPageToken {
    private static let prefix = "v1:"

    static func encode(_ edge: Date) -> String {
        let hex = String(edge.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        return prefix + String(repeating: "0", count: 16 - hex.count) + hex
    }

    /// The boundary [token] holds, or nil when it is malformed.
    static func decode(_ token: String) -> Date? {
        guard token.hasPrefix(prefix) else { return nil }
        let hex = token.dropFirst(prefix.count)
        // UInt64(_:radix:) also accepts a sign, so check the digits first.
        guard hex.count == 16, hex.allSatisfy(\.isHexDigit), let bits = UInt64(hex, radix: 16) else {
            return nil
        }
        let interval = Double(bitPattern: bits)
        return interval.isFinite ? Date(timeIntervalSinceReferenceDate: interval) : nil
    }
}
