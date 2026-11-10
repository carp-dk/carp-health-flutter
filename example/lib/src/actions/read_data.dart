part of '../../main.dart';

/// Reading health data: page by page, a single data point by UUID, today's steps and interval data.
extension _ReadDataActions on HealthAppState {
  /// Fetch data points from the health plugin and show them in the app.
  Future<void> fetchData() async {
    setState(() => _state = AppState.FETCHING_DATA);

    // get data within the last 24 hours
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    // Clear old data points
    _healthDataList.clear();

    try {
      // fetch health data page by page, so memory stays bounded however much
      // data there is (getHealthDataFromTypes returns all points in one list)
      var total = 0;
      await for (final page in health.getHealthDataPages(
        types: types,
        startTime: yesterday,
        endTime: now,
        recordingMethodsToFilter: recordingMethodsToFilter,
      )) {
        total += page.points.length;

        // keep the 100 newest data points
        _healthDataList
          ..addAll(page.points)
          ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
        if (_healthDataList.length > 100) {
          _healthDataList.removeRange(100, _healthDataList.length);
        }
      }

      debugPrint(
        'Total number of data points: $total. '
        '${total > 100 ? 'Only showing the first 100.' : ''}',
      );
    } on HealthPlatformException catch (error) {
      // Health Connect or HealthKit reported an error, for example
      // HealthErrorCode.rateLimitExceeded, which is worth retrying later.
      debugPrint(
        "Exception in getHealthDataPages: $error - "
        "errorCode: ${error.errorCode}, retryable: ${error.isRetryable}",
      );
    } catch (error) {
      debugPrint("Exception in getHealthDataPages: $error");
    }

    // filter out duplicates
    _healthDataList = health.removeDuplicates(_healthDataList);

    for (var data in _healthDataList) {
      debugPrint(data.toJson().toString());
    }

    // update the UI to display the results
    setState(() {
      _state = _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
    });
  }

  /// Fetch single data point by UUID and type.
  Future<void> fetchDataByUUID(BuildContext context, {required String uuid, required HealthDataType type}) async {
    try {
      // fetch health data
      HealthDataPoint? healthPoint = await health.getHealthDataByUUID(uuid: uuid, type: type);

      if (healthPoint != null) {
        // save all the new data points (only the first 100)
        if (context.mounted) openDetailBottomSheet(context, healthPoint);
      }
    } catch (error) {
      debugPrint("Exception in getHealthDataByUUID: $error");
    }
  }

  /// Fetch steps from the health plugin and show them in the app.
  Future<void> fetchStepData() async {
    int? steps;

    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    bool stepsPermission = await health.hasPermissions([HealthDataType.STEPS]) ?? false;
    if (!stepsPermission) {
      stepsPermission = await health.requestAuthorization([HealthDataType.STEPS]);
    }

    if (stepsPermission) {
      try {
        // 0 if there are no steps today
        steps = await health.getTotalStepsInInterval(
          midnight,
          now,
          includeManualEntry: !recordingMethodsToFilter.contains(RecordingMethod.manual),
        );
        debugPrint('Total number of steps: $steps');
      } on HealthPlatformException catch (error) {
        // Health Connect or HealthKit reported an error, for example
        // HealthErrorCode.rateLimitExceeded, which is worth retrying later.
        debugPrint(
          "Exception in getTotalStepsInInterval: $error - "
          "errorCode: ${error.errorCode}, retryable: ${error.isRetryable}",
        );
      } catch (error) {
        debugPrint("Exception in getTotalStepsInInterval: $error");
      }

      // steps is null if they could not be read
      setState(() {
        _nofSteps = steps ?? 0;
        _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      });
    } else {
      debugPrint("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Future<void> getIntervalBasedData() async {
    final startDate = DateTime.now().subtract(const Duration(days: 7));
    final endDate = DateTime.now();

    List<HealthDataPoint> healthDataResponse = await health.getHealthIntervalDataFromTypes(
      startDate: startDate,
      endDate: endDate,
      types: [HealthDataType.BLOOD_OXYGEN, HealthDataType.STEPS],
      interval: 86400, // 86400 seconds = 1 day
      // recordingMethodsToFilter: recordingMethodsToFilter,
    );
    debugPrint(
      'Total number of interval data points: ${healthDataResponse.length}. '
      '${healthDataResponse.length > 100 ? 'Only showing the first 100.' : ''}',
    );

    debugPrint("Interval data points: ");
    for (var data in healthDataResponse) {
      debugPrint(toJsonString(data));
    }
    healthDataResponse.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    _healthDataList.clear();
    _healthDataList.addAll((healthDataResponse.length < 100) ? healthDataResponse : healthDataResponse.sublist(0, 100));

    for (var data in _healthDataList) {
      debugPrint(toJsonString(data));
    }

    setState(() {
      _state = _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
    });
  }
}
