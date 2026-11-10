import Flutter
import HealthKit
import XCTest

@testable import health

/// The types requestAuthorization and getRequestStatusForAuthorization ask HealthKit for. Both
/// build them with authorizationTypes, as the request status describes the types requested.
class AuthorizationTests: XCTestCase {
  private let operations: HealthDataOperations = {
    let plugin = HealthPlugin()
    plugin.initializeTypes()
    return HealthDataOperations(
      healthStore: HKHealthStore(), dataTypesDict: plugin.dataTypesDict,
      characteristicsTypesDict: plugin.characteristicsTypesDict, nutritionList: plugin.nutritionList
    )
  }()
  private let steps = HKQuantityType.quantityType(forIdentifier: .stepCount)!
  private let birthDate = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!

  /// The arguments of a request for [types] with the access at the same index in [permissions].
  private func arguments(_ types: [String], _ permissions: [Int]) -> [String: Any] {
    ["types": types, "permissions": permissions]
  }

  private func authorizationTypes(_ types: [String], _ permissions: [Int]) throws
    -> (toShare: Set<HKSampleType>, read: Set<HKObjectType>)
  {
    try operations.authorizationTypes(
      call: FlutterMethodCall(methodName: "requestAuthorization", arguments: arguments(types, permissions))
    )
  }

  func testAccessIsReadWriteOrBoth() throws {
    let read = try authorizationTypes(["STEPS"], [0])
    XCTAssertEqual(read.read, [steps])
    XCTAssertEqual(read.toShare, [])
    let write = try authorizationTypes(["STEPS"], [1])
    XCTAssertEqual(write.read, [])
    XCTAssertEqual(write.toShare, [steps])
    let both = try authorizationTypes(["STEPS"], [2])
    XCTAssertEqual(both.read, [steps])
    XCTAssertEqual(both.toShare, [steps])
  }

  func testNutritionAsksForEveryNutrient() throws {
    let nutrients = Set(operations.nutritionList.compactMap { operations.dataTypesDict[$0] })
    XCTAssertFalse(nutrients.isEmpty)
    let types = try authorizationTypes(["NUTRITION"], [2])
    XCTAssertEqual(types.toShare, nutrients)
    XCTAssertEqual(types.read, Set(nutrients.map { $0 as HKObjectType }))
  }

  func testCharacteristicTypesAreOnlyRead() throws {
    XCTAssertEqual(try authorizationTypes(["BIRTH_DATE"], [0]).read, [birthDate])
    let readWrite = try authorizationTypes(["BIRTH_DATE"], [2])
    XCTAssertEqual(readWrite.read, [birthDate])
    XCTAssertEqual(readWrite.toShare, [])
    let message = pluginErrorMessage(try authorizationTypes(["BIRTH_DATE"], [1]))
    XCTAssertTrue(
      message?.hasPrefix("Cannot request write permission for characteristic type") == true, message ?? "nil"
    )
  }

  func testTypesThisVersionDoesNotHaveAreLeftOut() throws {
    let types = try authorizationTypes(["STEPS", "NOT_A_HEALTHKIT_TYPE"], [0, 2])
    XCTAssertEqual(types.read, [steps])
    XCTAssertEqual(types.toShare, [])
  }

  func testArgumentsOfDifferentLengthsAreInvalid() {
    XCTAssertEqual(pluginErrorMessage(try authorizationTypes(["STEPS"], [0, 1])), "Invalid Arguments!")
  }

  func testARequestWithoutTypesIsAnsweredWithoutHealthKit() throws {
    // HealthKit raises an exception, which crashes the app, when it is asked about no types.
    for types in [[], ["NOT_A_HEALTHKIT_TYPE"]] {
      let args = arguments(types, types.map { _ in 0 })
      XCTAssertEqual(
        try replies(to: operations.requestAuthorization, method: "requestAuthorization", arguments: args)
          as? [Bool],
        [false]
      )
      XCTAssertEqual(
        try replies(
          to: operations.getRequestStatusForAuthorization, method: "getRequestStatusForAuthorization",
          arguments: args
        ) as? [String],
        ["unnecessary"]
      )
    }
  }
}
