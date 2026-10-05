import Flutter
import HealthKit
import UIKit
import XCTest

@testable import health

class RunnerTests: XCTestCase {

  /// Several names store the same HealthKit type (RUNNING and RUNNING_TREADMILL both store
  /// `.running`). A workout read back from HealthKit must always get HealthKit's own name.
  func testWorkoutActivityTypeIsReadBackUnderItsHealthKitName() {
    let plugin = HealthPlugin()
    plugin.initializeTypes()

    let names = HealthDataReader.workoutActivityTypeNames(from: plugin.workoutActivityTypeMap)

    XCTAssertEqual(names[.running], "RUNNING")
    XCTAssertEqual(names[.climbing], "CLIMBING")
    XCTAssertEqual(names[.swimming], "SWIMMING")
  }

  func testEveryHealthKitWorkoutActivityTypeKeepsAName() {
    let plugin = HealthPlugin()
    plugin.initializeTypes()

    let names = HealthDataReader.workoutActivityTypeNames(from: plugin.workoutActivityTypeMap)

    XCTAssertEqual(Set(names.keys), Set(plugin.workoutActivityTypeMap.values))
    for (type, name) in names {
      XCTAssertEqual(plugin.workoutActivityTypeMap[name], type)
    }
  }

}
