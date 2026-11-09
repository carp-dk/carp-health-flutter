part of '../../health.dart';

/// Part of [Health]: tracking the changes in Health Connect with a changes
/// token. Android only.
// ignore: library_private_types_in_public_api
mixin HealthChangeTracking on _HealthReadSupport {
  /// Create a Health Connect changes token for the provided [types].
  ///
  /// Android only. Returns null on iOS or if an error occurs.
  Future<String?> getChangesToken({required List<HealthDataType> types}) async {
    if (Platform.isIOS) return null;

    await _checkIfHealthConnectAvailableOnAndroid();
    if (types.isEmpty) {
      throw ArgumentError('The list of [types] must not be empty.');
    }

    final normalizedTypes = _normalizeTypesForChanges(types);
    if (normalizedTypes.isEmpty) {
      throw ArgumentError('No supported types supplied for change token creation.');
    }

    for (final type in normalizedTypes) {
      await _checkIfDataTypeAvailableOnDevice(type);
      if (!isDataTypeAvailable(type)) {
        throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
      }
    }

    try {
      return await Health._channel.invokeMethod<String>('getChangesToken', {
        'types': normalizedTypes.map((type) => type.name).toList(),
      });
    } catch (e) {
      debugPrint('$runtimeType - Exception in getChangesToken(): $e');
      return null;
    }
  }

  /// Fetch the next page of changes for a previously created token.
  ///
  /// Android only. Returns null on iOS or if an error occurs, for example when
  /// Health Connect's API quota is used up; try again later.
  ///
  /// [HealthChangesResponse.changesTokenExpired] means the token can no longer
  /// be used: read the data since your last sync (for example with
  /// [Health.getHealthDataPages]) and create a new token. This is also returned
  /// when Health Connect cannot return the pending changes because they are too
  /// large ("Too many records in the cursor"), so poll often enough to keep the
  /// batches small.
  Future<HealthChangesResponse?> getChanges({required String changesToken, bool includeSelf = false}) async {
    if (Platform.isIOS) return null;

    final mode = isolateMode;
    await _checkIfHealthConnectAvailableOnAndroid();
    if (changesToken.isEmpty) {
      throw ArgumentError('The [changesToken] must not be empty.');
    }

    try {
      return await _invokeAndParse(
        'getChanges',
        {'changesToken': changesToken, 'includeSelf': includeSelf},
        _parseChanges,
        _ParseRequest(null, null, await _resolveDeviceId()),
        mode,
      );
    } on HealthException catch (e) {
      debugPrint('$runtimeType - Exception in getChanges(): $e');
      if (e.errorCode == HealthErrorCode.dataTooLarge) {
        // Retrying the same token would fail the same way.
        return HealthChangesResponse(
          changes: const [],
          nextChangesToken: changesToken,
          hasMore: false,
          changesTokenExpired: true,
        );
      }
      return null;
    } catch (e) {
      debugPrint('$runtimeType - Exception in getChanges(): $e');
      return null;
    }
  }

  List<HealthDataType> _normalizeTypesForChanges(List<HealthDataType> types) {
    final normalized = List<HealthDataType>.from(types, growable: true);

    final bmiIndex = normalized.indexOf(HealthDataType.BODY_MASS_INDEX);
    if (bmiIndex != -1) {
      normalized.removeAt(bmiIndex);
      if (!normalized.contains(HealthDataType.WEIGHT)) {
        normalized.add(HealthDataType.WEIGHT);
      }
      if (!normalized.contains(HealthDataType.HEIGHT)) {
        normalized.add(HealthDataType.HEIGHT);
      }
    }

    if (normalized.contains(HealthDataType.WORKOUT_ROUTE) && !normalized.contains(HealthDataType.WORKOUT)) {
      normalized.add(HealthDataType.WORKOUT);
    }

    return normalized.toSet().toList();
  }
}
