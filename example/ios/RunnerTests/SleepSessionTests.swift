import Flutter
import HealthKit
import XCTest

@testable import health

/// HealthKit has no sleep session object: writeSleepSession saves in-bed samples for the session
/// without its out-of-bed stages and a sleep analysis sample per stage, all at once, and replies
/// once. Invalid arguments get one INVALID_ARGUMENT reply before any sample is created.
class SleepSessionTests: XCTestCase {
  private let writer = HealthDataWriter(
    healthStore: HKHealthStore(), dataTypesDict: [:], unitDict: [:], workoutActivityTypeMap: [:]
  )
  /// The start of the sessions below.
  private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

  func testEachStageHasItsSleepValue() throws {
    let stages = [
      stage("SLEEP_AWAKE_IN_BED", 0, 10), stage("SLEEP_LIGHT", 10, 60), stage("SLEEP_DEEP", 60, 120),
      stage("SLEEP_REM", 120, 180), stage("SLEEP_AWAKE", 180, 190), stage("SLEEP_OUT_OF_BED", 190, 200),
      stage("SLEEP_ASLEEP", 200, 300), stage("SLEEP_UNKNOWN", 300, 360),
    ]
    // In bed without the out-of-bed stage, which has no sample, nor has the unknown stage.
    let samples = try writer.sleepSessionSamples(
      start: t0, end: at(480), stages: stages, recordingMethod: 2
    )
    XCTAssertEqual(
      describe(samples),
      [
        "inBed 0-190", "inBed 200-480", "awake 0-10", "asleepCore 10-60", "asleepDeep 60-120",
        "asleepREM 120-180", "awake 180-190", "asleepUnspecified 200-300",
      ]
    )
  }

  func testBeforeIOS16StagesAreAsleep() throws {
    // iOS 15 has no core, deep or REM sleep.
    let stages = [stage("SLEEP_LIGHT", 0, 60), stage("SLEEP_DEEP", 60, 120), stage("SLEEP_REM", 120, 180)]
    let samples = try writer.sleepSessionSamples(
      start: t0, end: at(180), stages: stages, recordingMethod: 2, sleepStages: false
    )
    XCTAssertEqual(
      describe(samples),
      ["inBed 0-180", "asleepUnspecified 0-60", "asleepUnspecified 60-120", "asleepUnspecified 120-180"]
    )
  }

  func testInBedLeavesOutOutOfBed() throws {
    func inBed(_ stages: [SleepSessionStage]) throws -> [String] {
      try describe(writer.sleepSessionSamples(start: t0, end: at(480), stages: stages, recordingMethod: 2))
    }
    // No empty in-bed sample before or after a stage at the start or end of the session.
    XCTAssertEqual(try inBed([stage("SLEEP_OUT_OF_BED", 0, 30)]), ["inBed 30-480"])
    XCTAssertEqual(try inBed([stage("SLEEP_OUT_OF_BED", 450, 480)]), ["inBed 0-450"])
    XCTAssertEqual(try inBed([stage("SLEEP_OUT_OF_BED", 0, 480)]), [])
    XCTAssertEqual(try inBed([]), ["inBed 0-480"])
    XCTAssertEqual(
      try inBed([stage("SLEEP_OUT_OF_BED", 60, 90), stage("SLEEP_OUT_OF_BED", 90, 120)]),
      ["inBed 0-60", "inBed 120-480"]
    )
  }

  func testUncoveredParts() {
    // Unsorted, overlapping and outside the range, which the Dart side does not send.
    let parts = HealthDataWriter.uncoveredParts(
      of: (at(0), at(100)),
      by: [(at(50), at(60)), (at(-10), at(10)), (at(55), at(70)), (at(90), at(200)), (at(300), at(400))]
    )
    XCTAssertEqual(parts.map { "\(minutes($0.start))-\(minutes($0.end))" }, ["10-50", "70-90"])
    XCTAssertEqual(HealthDataWriter.uncoveredParts(of: (at(0), at(0)), by: []).count, 0)
  }

  func testRecordingMethodSetsWasUserEntered() throws {
    for (recordingMethod, wasUserEntered) in [(3, true), (2, false)] {
      let samples = try writer.sleepSessionSamples(
        start: t0, end: at(60), stages: [stage("SLEEP_DEEP", 0, 30)], recordingMethod: recordingMethod
      )
      XCTAssertEqual(samples.count, 2)
      for sample in samples {
        XCTAssertEqual(sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool, wasUserEntered)
      }
    }
  }

  func testUnknownStageTypeRepliesOnce() throws {
    for type in ["SLEEP_IN_BED", "SLEEP_SESSION", "STEPS"] {
      let stages = [stage(type, 0, 30)]
      XCTAssertEqual(
        pluginErrorMessage(
          try writer.sleepSessionSamples(start: t0, end: at(60), stages: stages, recordingMethod: 2)
        ),
        "\(type) is not a sleep stage type"
      )
      // As the Dart side sends the arguments: null for a title or notes that is not set.
      try assertRepliesInvalidArgumentOnce(session(stages: [stageArgument(type, 0, 30)], title: NSNull()))
    }
  }

  func testMalformedStageRepliesOnce() throws {
    let noEnd: [String: Any] = ["type": "SLEEP_DEEP", "startTime": milliseconds(t0)]
    try assertRepliesInvalidArgumentOnce(session(stages: [noEnd]))
    try assertRepliesInvalidArgumentOnce(session(stages: ["SLEEP_DEEP"]))
  }

  func testDatesAreCheckedBeforeAnySample() throws {
    // Sleep analysis samples can last 4 days; HealthKit raises an exception for longer ones.
    try assertRepliesInvalidArgumentOnce(session(end: 5 * 24 * 60, stages: []))
    try assertRepliesInvalidArgumentOnce(session(stages: [stageArgument("SLEEP_DEEP", 30, 10)]))
    let toDistantFuture: [String: Any] = [
      "type": "SLEEP_DEEP", "startTime": milliseconds(t0), "endTime": milliseconds(.distantFuture),
    ]
    try assertRepliesInvalidArgumentOnce(session(stages: [toDistantFuture]))
  }

  func testMissingArgumentIsAWriteError() throws {
    var arguments = session(stages: [])
    arguments["stages"] = nil
    XCTAssertEqual(
      pluginErrorMessage(
        try replies(to: writer.writeSleepSession, method: "writeSleepSession", arguments: arguments)
      ),
      "Invalid Arguments"
    )
    // The plugin replies to that with a WRITE_ERROR, as for the other writes.
    var sent = [Any?]()
    HealthPlugin().handle(FlutterMethodCall(methodName: "writeSleepSession", arguments: arguments)) {
      sent.append($0)
    }
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual((sent.first as? FlutterError)?.code, "WRITE_ERROR")
  }

  func testSessionOutOfBedRepliesTrue() throws {
    let sent = try replies(
      to: writer.writeSleepSession, method: "writeSleepSession",
      arguments: session(stages: [stageArgument("SLEEP_OUT_OF_BED", 0, 480)], notes: "Up all night")
    )
    XCTAssertEqual(sent.count, 1)
    XCTAssertEqual(sent.first as? Bool, true)
  }

  func testSavesAllSamplesAtOnceAndRepliesOnce() throws {
    // The reply is whether HealthKit saved them.
    for success in [true, false] {
      let store = SaveRecordingStore(success: success)
      let recordingWriter = HealthDataWriter(
        healthStore: store, dataTypesDict: [:], unitDict: [:], workoutActivityTypeMap: [:]
      )
      let replied = expectation(description: "reply")
      replied.assertForOverFulfill = true
      let call = FlutterMethodCall(
        methodName: "writeSleepSession", arguments: session(stages: [stageArgument("SLEEP_REM", 60, 90)])
      )
      try recordingWriter.writeSleepSession(call: call) { reply in
        XCTAssertEqual(reply as? Bool, success)
        replied.fulfill()
      }
      wait(for: [replied], timeout: 5)
      let saved = store.saves.map { objects in describe(objects.compactMap { $0 as? HKCategorySample }) }
      XCTAssertEqual(saved, [["inBed 0-480", "asleepREM 60-90"]])
    }
  }

  /// The date [minutes] after t0.
  private func at(_ minutes: Int) -> Date {
    t0 + TimeInterval(minutes * 60)
  }

  private func minutes(_ date: Date) -> Int {
    Int(date.timeIntervalSince(t0) / 60)
  }

  private func stage(_ type: String, _ start: Int, _ end: Int) -> SleepSessionStage {
    SleepSessionStage(type: type, start: at(start), end: at(end))
  }

  /// A stage as the Dart side sends it.
  private func stageArgument(_ type: String, _ start: Int, _ end: Int) -> [String: Any] {
    ["type": type, "startTime": milliseconds(at(start)), "endTime": milliseconds(at(end))]
  }

  /// The arguments of a session from t0 to [end] minutes after it, as the Dart side sends them.
  private func session(
    end: Int = 480, stages: [Any], title: Any = NSNull(), notes: Any = NSNull()
  ) -> [String: Any] {
    [
      "startTime": milliseconds(t0), "endTime": milliseconds(at(end)), "title": title, "notes": notes,
      "recordingMethod": 2, "stages": stages,
    ]
  }

  /// Each sample as its sleep analysis value and its minutes after t0, e.g. "inBed 0-480".
  private func describe(_ samples: [HKCategorySample]) -> [String] {
    let names: [Int: String] = [
      HKCategoryValueSleepAnalysis.inBed.rawValue: "inBed",
      HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: "asleepUnspecified",
      HKCategoryValueSleepAnalysis.awake.rawValue: "awake",
      HKCategoryValueSleepAnalysis.asleepCore.rawValue: "asleepCore",
      HKCategoryValueSleepAnalysis.asleepDeep.rawValue: "asleepDeep",
      HKCategoryValueSleepAnalysis.asleepREM.rawValue: "asleepREM",
    ]
    return samples.map {
      "\(names[$0.value] ?? "\($0.value)") \(minutes($0.startDate))-\(minutes($0.endDate))"
    }
  }

  /// Asserts that writeSleepSession replies a single INVALID_ARGUMENT error before it returns. A
  /// write that went on would create the samples, which may raise an exception and end the test run.
  private func assertRepliesInvalidArgumentOnce(_ arguments: [String: Any], line: UInt = #line) throws {
    let sent = try replies(to: writer.writeSleepSession, method: "writeSleepSession", arguments: arguments)
    XCTAssertEqual(sent.count, 1, line: line)
    XCTAssertEqual((sent.first as? FlutterError)?.code, "INVALID_ARGUMENT", line: line)
  }
}

/// A health store that records what it is asked to save, without HealthKit, and answers [success].
private final class SaveRecordingStore: HKHealthStore, @unchecked Sendable {
  private let success: Bool
  private(set) var saves = [[HKObject]]()

  init(success: Bool) {
    self.success = success
    super.init()
  }

  override func save(
    _ objects: [HKObject], withCompletion completion: @escaping @Sendable (Bool, (any Error)?) -> Void
  ) {
    saves.append(objects)
    completion(success, nil)
  }
}
