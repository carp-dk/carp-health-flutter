import Flutter
import Foundation
import HealthKit

@testable import health

// Helpers shared by the test cases of the plugin's Swift code. The test cases build HealthKit
// objects without saving them, so they need no HealthKit authorization.

/// The message of the PluginError the expression throws, nil when it throws none.
func pluginErrorMessage<T>(_ expression: @autoclosure () throws -> T) -> String? {
  do {
    _ = try expression()
  } catch {
    return (error as? PluginError)?.message
  }
  return nil
}

/// The replies a write sends before it returns. Invalid arguments are replied to right away,
/// before anything is saved.
func replies(
  to write: (FlutterMethodCall, @escaping FlutterResult) throws -> Void,
  method: String, arguments: [String: Any]
) rethrows -> [Any?] {
  var replies = [Any?]()
  try write(FlutterMethodCall(methodName: method, arguments: arguments)) { replies.append($0) }
  return replies
}

/// A date as the Dart side sends it: milliseconds since the epoch.
func milliseconds(_ date: Date) -> Int {
  Int(date.timeIntervalSince1970 * 1000)
}

/// A health store that keeps the queries it is given and the objects it is asked to save, without
/// HealthKit: it runs no query, and answers [saveSucceeds] to each save.
final class RecordingHealthStore: HKHealthStore, @unchecked Sendable {
  private let saveSucceeds: Bool
  private(set) var queries = [HKQuery]()
  private(set) var saved = [HKObject]()

  init(saveSucceeds: Bool = true) {
    self.saveSucceeds = saveSucceeds
    super.init()
  }

  override func execute(_ query: HKQuery) {
    queries.append(query)
  }

  override func save(
    _ object: HKObject, withCompletion completion: @escaping @Sendable (Bool, (any Error)?) -> Void
  ) {
    saved.append(object)
    completion(saveSucceeds, nil)
  }
}
