part of '../main.dart';

/// The app's state. The actions and the parts of the UI that use it are private extensions on this class,
/// one file per group in `src/actions/` and `src/widgets/`.
class HealthAppState extends State<HealthApp> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 0;
  List<RecordingMethod> recordingMethodsToFilter = [];
  String? _changesToken;
  String? _previousChangesToken;
  bool _changesTokenExpired = false;
  bool _changesHasMore = false;
  final List<HealthChange> _changes = [];
  final List<HealthDataType> _changeTypes = const [HealthDataType.STEPS, HealthDataType.WORKOUT];
  final Map<String, HealthDataPoint> _syncedDataById = {};
  int _lastBeforeCount = 0;
  int _lastAfterCount = 0;
  int _lastInserted = 0;
  int _lastUpdated = 0;
  int _lastRemoved = 0;
  int _lastAppliedUpserts = 0;
  int _lastAppliedDeletes = 0;
  DateTime? _lastChangesAt;

  // status texts set by the Health Connect and skin temperature checks
  Widget _contentHealthConnectStatus = const Text('No status, click getHealthConnectSdkStatus to get the status.');

  Widget _contentSkinTemperatureFeatureStatus = const Text(
    'No status, click "Check Skin Temp Feature" to get the status.',
  );

  // Whether the installed Health Connect has mindfulness sessions and skin temperature, set by
  // _checkHealthConnectFeatures. Until it has checked, [types] leaves them out.
  bool _hasMindfulnessSessions = false;
  bool _hasSkinTemperature = false;

  // All types available depending on platform (iOS ot Android).
  List<HealthDataType> get types {
    if (Platform.isAndroid) {
      // Without the feature, reading, writing or deleting the type throws a HealthException
      // (notSupported), which would fail the read of all types.
      return [
        for (final type in dataTypesAndroid)
          if ((type != HealthDataType.MINDFULNESS || _hasMindfulnessSessions) &&
              (type != HealthDataType.SKIN_TEMPERATURE || _hasSkinTemperature))
            type,
      ];
    }
    if (!Platform.isIOS) return [];

    final iosTypes = List<HealthDataType>.from(dataTypesIOS);
    if (!_isIOS16OrNewer) {
      iosTypes.removeWhere(
        (type) => const {
          HealthDataType.WATER_TEMPERATURE,
          HealthDataType.UNDERWATER_DEPTH,
          HealthDataType.UV_INDEX,
          HealthDataType.SLEEP_WRIST_TEMPERATURE,
        }.contains(type),
      );
    }

    return iosTypes;
  }

  // // Or specify specific types
  // static final types = [
  //   HealthDataType.WEIGHT,
  //   HealthDataType.STEPS,
  //   HealthDataType.HEIGHT,
  //   HealthDataType.BLOOD_GLUCOSE,
  //   HealthDataType.WORKOUT,
  //   HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  //   HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  //   // Uncomment this line on iOS - only available on iOS
  //   // HealthDataType.AUDIOGRAM
  // ];

  // Set up corresponding permissions

  // READ only
  // List<HealthDataAccess> get permissions =>
  //     types.map((e) => HealthDataAccess.READ).toList();

  // Or both READ and WRITE
  List<HealthDataAccess> get permissions => types
      .map(
        (type) =>
            // can only request READ permissions to the following list of types on iOS
            [
              HealthDataType.GENDER,
              HealthDataType.BLOOD_TYPE,
              HealthDataType.BIRTH_DATE,
              HealthDataType.APPLE_MOVE_TIME,
              HealthDataType.APPLE_STAND_HOUR,
              HealthDataType.APPLE_STAND_TIME,
              HealthDataType.WALKING_HEART_RATE,
              HealthDataType.ELECTROCARDIOGRAM,
              HealthDataType.HIGH_HEART_RATE_EVENT,
              HealthDataType.LOW_HEART_RATE_EVENT,
              HealthDataType.IRREGULAR_HEART_RATE_EVENT,
              HealthDataType.EXERCISE_TIME,
              HealthDataType.SLEEP_WRIST_TEMPERATURE,
            ].contains(type)
            ? HealthDataAccess.READ
            : HealthDataAccess.READ_WRITE,
      )
      .toList();

  @override
  void initState() {
    // configure the health plugin before use and check the Health Connect status
    health.configure();
    health.getHealthConnectSdkStatus();
    _checkHealthConnectFeatures();

    super.initState();
  }

  /// Checks which of the types that Health Connect added after its first release the installed
  /// Health Connect has: mindfulness sessions and skin temperature.
  Future<void> _checkHealthConnectFeatures() async {
    if (!Platform.isAndroid) return;
    final hasMindfulnessSessions = await health.isMindfulnessSessionAvailable();
    final hasSkinTemperature = await health.isSkinTemperatureAvailable();
    if (!mounted) return;
    setState(() {
      _hasMindfulnessSessions = hasMindfulnessSessions;
      _hasSkinTemperature = hasSkinTemperature;
    });
  }

  /// Overridden without `@protected` so the actions and widgets, which are extensions on this class, can call it:
  /// the analyzer reports protected members used in extensions.
  @override
  void setState(VoidCallback fn) => super.setState(fn);

  bool get _isIOS16OrNewer {
    if (!Platform.isIOS) return false;
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    final majorVersion = int.tryParse(match?.group(1) ?? '');
    return (majorVersion ?? 0) >= 16;
  }

  // UI building below

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Health Example')),
        body: Column(
          children: [
            _actionButtons,
            const Divider(thickness: 3),
            if (_state == AppState.DATA_READY) _dataFiltration,
            if (_state == AppState.STEPS_READY) _stepsFiltration,
            Expanded(child: Center(child: _content)),
          ],
        ),
      ),
    );
  }
}
