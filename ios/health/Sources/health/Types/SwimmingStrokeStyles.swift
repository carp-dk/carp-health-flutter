import HealthKit

/// The names of the stroke styles of swimming laps (SwimmingStrokeStyle on the Dart side) and the
/// HealthKit stroke styles (HKSwimmingStrokeStyle) that laps are written and read with. HealthKit
/// keeps a lap's style in the HKMetadataKeySwimmingStrokeStyle metadata of its lap event.
enum SwimmingStrokeStyles {
    /// Whether HealthKit has the kickboard style: iOS 16 and later.
    static var hasKickboard: Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    /// The style a lap written as [name] is saved with, nil for a name that is no stroke style.
    /// HealthKit has no style for other, nor kickboard before iOS 16: those laps are saved as
    /// unknown, and read back as unknown.
    /// - Parameter kickboard: Whether HealthKit has the kickboard style (hasKickboard)
    static func style(named name: String, kickboard: Bool = hasKickboard) -> HKSwimmingStrokeStyle? {
        switch name {
        case "unknown", "other": return .unknown
        case "mixed": return .mixed
        case "freestyle": return .freestyle
        case "backstroke": return .backstroke
        case "breaststroke": return .breaststroke
        case "butterfly": return .butterfly
        case "kickboard":
            if #available(iOS 16.0, *), kickboard {
                return .kickboard
            }
            return .unknown
        default: return nil
        }
    }

    /// The name a lap of [style] reads as: unknown for a style HealthKit added after this plugin.
    static func name(of style: HKSwimmingStrokeStyle) -> String {
        switch style {
        case .unknown: return "unknown"
        case .mixed: return "mixed"
        case .freestyle: return "freestyle"
        case .backstroke: return "backstroke"
        case .breaststroke: return "breaststroke"
        case .butterfly: return "butterfly"
        case .kickboard: return "kickboard"
        @unknown default: return "unknown"
        }
    }
}
