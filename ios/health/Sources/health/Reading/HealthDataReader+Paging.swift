import Flutter
import HealthKit

extension HealthDataReader {
    /// Reads one page of a data type, so the Dart side can walk ranges of any size without
    /// holding them in memory at once. Every sample type is paged by end date (keyset paging):
    /// newest first (getData's order) or oldest first, and the page token holds the end date
    /// the next page continues past. A page whose last sample shares its end date with samples
    /// beyond the page is completed with them, so no sample is skipped or read twice.
    /// Characteristics (BIRTH_DATE, GENDER, BLOOD_TYPE) are a single page whatever the window.
    /// Replies go out from HealthKit's queues: encoding a large reply on the main thread would
    /// stall the UI.
    /// - Parameters:
    ///   - call: Flutter method call with getData's arguments plus 'pageSize', 'pageToken' and
    ///     'newestFirst'
    ///   - result: Flutter result callback returning ['data': [...], 'nextPageToken': token or nil]
    func getDataPage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let request: DataPageRequest
        do {
            request = try DataPageRequest(call.arguments)
        } catch {
            let message = (error as? PluginError)?.message ?? "\(error)"
            result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
            return
        }
        let dataTypeKey = request.dataTypeKey

        if let point = characteristicDictionary(dataTypeKey, from: request.start, to: request.end) {
            result(pageReply([point], nextPageEdge: nil))
            return
        }

        guard let sampleType = dataTypesDict[dataTypeKey] else {
            result(
                FlutterError(
                    code: "NOT_SUPPORTED",
                    message: "Data type \(dataTypeKey) is not available on this device",
                    details: nil
                )
            )
            return
        }

        let unit = request.dataUnitKey.flatMap { unitDict[$0] }
        if let unitError = incompatibleUnitError(
            sampleType, unit: unit, dataTypeKey: dataTypeKey, unitKey: request.dataUnitKey
        ) {
            result(unitError)
            return
        }

        // No sample starts in an empty window (the predicate is start <= startDate < end).
        guard request.start < request.end else {
            result(pageReply([], nextPageEdge: nil))
            return
        }

        let operation = "reading \(dataTypeKey)"
        let limit = min(request.pageSize, HealthDataReader.pageCaps[dataTypeKey] ?? HealthDataReader.maxPageSize)
        let base = samplePredicate(
            from: request.start, to: request.end, includeManualEntry: request.includeManualEntry,
            dataTypeKey: dataTypeKey
        )
        var predicate = base
        if let edge = request.edge {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                base,
                NSPredicate(
                    format: request.newestFirst ? "%K < %@" : "%K > %@", HKPredicateKeyPathEndDate, edge as NSDate
                ),
            ])
        }

        let reply: ([HKSample], Date?) -> Void = { samples, nextPageEdge in
            self.convertSamples(
                samples, dataTypeKey: dataTypeKey, unit: unit, includeManualEntry: request.includeManualEntry
            ) { converted in
                switch converted {
                case let .success(data):
                    result(self.pageReply(data, nextPageEdge: nextPageEdge))
                case let .failure(error):
                    // A failed page never carries partial data.
                    result(HealthUtilities.flutterError(for: error, operation: operation))
                }
            }
        }

        // One sample more than the page tells whether the page boundary splits samples sharing an end date.
        let query = HKSampleQuery(
            sampleType: sampleType, predicate: predicate, limit: limit + 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: !request.newestFirst)]
        ) { _, samplesOrNil, error in
            if let error {
                if HealthUtilities.isNoData(error) {
                    result(self.pageReply([], nextPageEdge: nil))
                } else {
                    result(HealthUtilities.flutterError(for: error, operation: operation))
                }
                return
            }
            let samples = samplesOrNil ?? []
            guard samples.count > limit else {
                reply(samples, nil)
                return
            }
            let page = Array(samples.prefix(limit))
            let boundary = page[limit - 1].endDate
            guard samples[limit].endDate == boundary else {
                reply(page, boundary)
                return
            }
            // The next page continues past the boundary, so every sample ending on it belongs to this one.
            let tied = NSCompoundPredicate(andPredicateWithSubpredicates: [
                base, NSPredicate(format: "%K == %@", HKPredicateKeyPathEndDate, boundary as NSDate),
            ])
            let tieQuery = HKSampleQuery(
                sampleType: sampleType, predicate: tied, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, tiedOrNil, tieError in
                if let tieError, !HealthUtilities.isNoData(tieError) {
                    result(HealthUtilities.flutterError(for: tieError, operation: operation))
                    return
                }
                var included = Set(page.map(\.uuid))
                var completed = page
                for sample in tiedOrNil ?? [] where included.insert(sample.uuid).inserted {
                    completed.append(sample)
                }
                reply(completed, boundary)
            }
            self.healthStore.execute(tieQuery)
        }

        healthStore.execute(query)
    }

    /// A getDataPage reply. A nil edge ends the type.
    private func pageReply(_ data: [Any], nextPageEdge: Date?) -> [String: Any] {
        var reply: [String: Any] = ["data": data, "nextPageToken": NSNull()]
        if let nextPageEdge {
            reply["nextPageToken"] = DataPageToken.encode(nextPageEdge)
        }
        return reply
    }
}

/// The arguments of one getDataPage call. Numbers are read as NSNumber: the standard codec
/// sends a Dart int that fits in 32 bits as Int32 and a larger one as Int64.
private struct DataPageRequest {
    let dataTypeKey: String
    let dataUnitKey: String?
    let start: Date
    let end: Date
    let includeManualEntry: Bool
    /// Target number of samples in the reply, 1 to HealthDataReader.maxPageSize.
    let pageSize: Int
    /// End date the previous page stopped at; nil on a type's first page.
    let edge: Date?
    /// Order by end date: newest first (getHealthDataFromTypes) or oldest first (getHealthDataPages).
    let newestFirst: Bool

    /// - Throws: PluginError naming the first missing or malformed argument.
    init(_ arguments: Any?) throws {
        guard let arguments = arguments as? NSDictionary else {
            throw PluginError(message: "Missing arguments")
        }
        // A null argument counts as a missing one.
        func value(_ key: String) -> Any? {
            let value = arguments[key]
            return value is NSNull ? nil : value
        }
        func number(_ key: String) throws -> NSNumber? {
            guard let raw = value(key) else { return nil }
            guard let number = raw as? NSNumber else {
                throw PluginError(message: "Argument \(key) must be a number")
            }
            return number
        }

        guard let dataTypeKey = value("dataTypeKey") as? String else {
            throw PluginError(message: "Missing required dataTypeKey argument")
        }
        guard let startTime = try number("startTime"), let endTime = try number("endTime") else {
            throw PluginError(message: "Missing required startTime or endTime argument")
        }
        let dataUnitKey = value("dataUnitKey")
        if dataUnitKey != nil, !(dataUnitKey is String) {
            throw PluginError(message: "Argument dataUnitKey must be a String")
        }
        var recordingMethodsToFilter = [Int]()
        if let methods = value("recordingMethodsToFilter") {
            guard let numbers = methods as? [NSNumber] else {
                throw PluginError(message: "Argument recordingMethodsToFilter must be a list of ints")
            }
            recordingMethodsToFilter = numbers.map(\.intValue)
        }
        var edge: Date?
        if let token = value("pageToken") {
            guard let token = token as? String, let decoded = DataPageToken.decode(token) else {
                throw PluginError(message: "Malformed pageToken: \(token)")
            }
            edge = decoded
        }
        var newestFirst = true
        if let order = value("newestFirst") {
            guard let order = order as? Bool else {
                throw PluginError(message: "Argument newestFirst must be a bool")
            }
            newestFirst = order
        }
        let pageSize = try number("pageSize")?.intValue ?? HealthDataReader.defaultPageSize

        self.dataTypeKey = dataTypeKey
        self.dataUnitKey = dataUnitKey as? String
        start = HealthUtilities.dateFromMilliseconds(startTime.doubleValue)
        end = HealthUtilities.dateFromMilliseconds(endTime.doubleValue)
        includeManualEntry = !recordingMethodsToFilter.contains(HealthConstants.RecordingMethod.manual.rawValue)
        self.pageSize = min(max(pageSize, 1), HealthDataReader.maxPageSize)
        self.edge = edge
        self.newestFirst = newestFirst
    }
}
