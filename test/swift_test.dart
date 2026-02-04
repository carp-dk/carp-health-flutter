import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:mockito/mockito.dart';

import 'mocks/device_info_mock.dart';

// Mock MethodChannel to simulate native responses
class MockMethodChannel extends Mock implements MethodChannel {
  String? lastMethod;
  dynamic lastArguments;
  final List<Map<String, dynamic>> recordedCalls = [];

  void resetCapturedCalls() {
    lastMethod = null;
    lastArguments = null;
    recordedCalls.clear();
  }

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    lastMethod = method;
    lastArguments = arguments;
    recordedCalls.add({'method': method, 'arguments': arguments});

    if (method == 'getData') {
      final dataTypeKey = (arguments as Map)['dataTypeKey'];
      switch (dataTypeKey) {
        case 'HEART_RATE':
          return Future.value(
            <Map<String, dynamic>>[
                  {
                    'uuid': 'test-uuid-1',
                    'value': 75.5,
                    'date_from': DateTime(2024, 9, 24, 12, 0).millisecondsSinceEpoch,
                    'date_to': DateTime(2024, 9, 24, 12, 0).millisecondsSinceEpoch,
                    'source_id': 'com.apple.Health',
                    'source_name': 'Health',
                    'recording_method': 2, // automatic
                    'metadata': {
                      'HKDeviceName': 'Apple Watch',
                      'HKExternalUUID': '123e4567-e89b-12d3-a456-426614174000',
                      'recording_method': 2,
                    },
                  },
                ]
                as T,
          );
        case 'WORKOUT':
          return Future.value(
            <Map<String, dynamic>>[
                  {
                    'uuid': 'test-uuid-2',
                    'workoutActivityType': 'RUNNING',
                    'totalEnergyBurned': 200.0,
                    'totalEnergyBurnedUnit': 'KILOCALORIE',
                    'totalDistance': 5000.0,
                    'totalDistanceUnit': 'METER',
                    'date_from': DateTime(2024, 9, 24, 12, 0).millisecondsSinceEpoch,
                    'date_to': DateTime(2024, 9, 24, 13, 0).millisecondsSinceEpoch,
                    'source_id': 'com.apple.Health',
                    'source_name': 'Health',
                    'recording_method': 2,
                    'metadata': {
                      'HKDeviceName': 'Apple Watch',
                      'complex': {'key': 'value', 'number': 42},
                    },
                  },
                ]
                as T,
          );
        case 'WORKOUT_ROUTE':
          return Future.value(
            <Map<String, dynamic>>[
                  {
                    'uuid': 'test-route-uuid',
                    'route': [
                      {
                        'latitude': 37.334900,
                        'longitude': -122.009020,
                        'timestamp': DateTime(2024, 9, 24, 12, 0).toUtc().millisecondsSinceEpoch,
                        'horizontalAccuracy': 5.0,
                        'verticalAccuracy': 8.0,
                        'speed': 1.4,
                        'course': 90.0,
                        'speedAccuracy': 0.5,
                        'courseAccuracy': 5.0,
                      },
                      {
                        'latitude': 37.335280,
                        'longitude': -122.008430,
                        'timestamp': DateTime(2024, 9, 24, 12, 2).toUtc().millisecondsSinceEpoch,
                        'horizontalAccuracy': 5.0,
                        'verticalAccuracy': 8.0,
                        'speed': 1.6,
                        'course': 120.0,
                      },
                    ],
                    'date_from': DateTime(2024, 9, 24, 12, 0).millisecondsSinceEpoch,
                    'date_to': DateTime(2024, 9, 24, 12, 30).millisecondsSinceEpoch,
                    'source_id': 'com.apple.Health',
                    'source_name': 'Health',
                    'recording_method': 2,
                    'metadata': {'route_point_count': 2, 'workout_uuid': 'test-workout-uuid'},
                    'workout_uuid': 'test-workout-uuid',
                  },
                ]
                as T,
          );
        case 'NUTRITION':
          return Future.value(
            <Map<String, dynamic>>[
                  {
                    'uuid': 'test-uuid-3',
                    'name': 'Lunch',
                    'meal_type': 'LUNCH',
                    'calories': 500.0,
                    'carbs': 60.0,
                    'protein': 20.0,
                    'date_from': DateTime(2024, 9, 24, 13, 0).millisecondsSinceEpoch,
                    'date_to': DateTime(2024, 9, 24, 13, 30).millisecondsSinceEpoch,
                    'source_id': 'com.apple.Health',
                    'source_name': 'Health',
                    'recording_method': 2,
                    'metadata': {
                      'HKFoodMeal': 'LUNCH',
                      'array': [1, 'test', false, 'DateTime.now()'],
                    },
                  },
                ]
                as T,
          );
        default:
          return Future.value(<Map<String, dynamic>>[] as T);
      }
    }

    if (method == 'startWorkoutRoute') {
      return Future.value('builder-123' as T);
    }

    if (method == 'insertWorkoutRouteData') {
      return Future.value(true as T);
    }

    if (method == 'finishWorkoutRoute') {
      return Future.value({'uuid': 'route-uuid-123'} as T);
    }

    if (method == 'discardWorkoutRoute') {
      return Future.value(true as T);
    }

    return Future.value(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Define the channel
  const channel = MethodChannel('flutter_health');
  final mockChannel = MockMethodChannel();

  setUp(() {
    // Use the updated method to set the mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) => mockChannel.invokeMethod(call.method, call.arguments),
    );
  });

  tearDown(() {
    // Clear the mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('Sanitization via getHealthDataFromTypes', () {
    final health = Health(deviceInfo: MockDeviceInfoPlugin());

    setUpAll(() async {
      await health.configure();
    });

    test('Test sanitization with simple metadata - HEART_RATE', () async {
      final dataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: DateTime(2024, 9, 24, 0, 0),
        endTime: DateTime(2024, 9, 24, 23, 59),
      );

      expect(dataPoints.length, 1);
      final hdp = dataPoints.first;
      expect(hdp.type, HealthDataType.HEART_RATE);
      expect(hdp.metadata, {
        'HKDeviceName': 'Apple Watch',
        'HKExternalUUID': '123e4567-e89b-12d3-a456-426614174000',
        'recording_method': 2,
      });
      expect(hdp.value, isA<NumericHealthValue>());
      expect((hdp.value as NumericHealthValue).numericValue, 75.5);
    });

    test('Test sanitization with nested metadata - WORKOUT', () async {
      final dataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: DateTime(2024, 9, 24, 0, 0),
        endTime: DateTime(2024, 9, 24, 23, 59),
      );

      expect(dataPoints.length, 1);
      final hdp = dataPoints.first;
      expect(hdp.type, HealthDataType.WORKOUT);
      expect(hdp.metadata, {
        'HKDeviceName': 'Apple Watch',
        'complex': {'key': 'value', 'number': 42},
        // 'unsupported' should be filtered out
      });
      expect(hdp.value, isA<WorkoutHealthValue>());
      final workoutValue = hdp.value as WorkoutHealthValue;
      expect(workoutValue.workoutActivityType, HealthWorkoutActivityType.RUNNING);
      expect(workoutValue.totalEnergyBurned, 200);
      expect(workoutValue.totalDistance, 5000);
    });

    test('Test sanitization with array in metadata - NUTRITION', () async {
      final dataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.NUTRITION],
        startTime: DateTime(2024, 9, 24, 0, 0),
        endTime: DateTime(2024, 9, 24, 23, 59),
      );

      expect(dataPoints.length, 1);
      final hdp = dataPoints.first;
      expect(hdp.type, HealthDataType.NUTRITION);
      expect(hdp.metadata, {
        'HKFoodMeal': 'LUNCH',
        'array': [1, 'test', false, 'DateTime.now()'], // 'DateTime.now()' should be filtered out
      });
      expect(hdp.value, isA<NutritionHealthValue>());
      final nutritionValue = hdp.value as NutritionHealthValue;
      expect(nutritionValue.calories, 500.0);
      expect(nutritionValue.carbs, 60.0);
      expect(nutritionValue.protein, 20.0);
    });

    test('Test sanitization with workout routes - WORKOUT_ROUTE', () async {
      final dataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT_ROUTE],
        startTime: DateTime(2024, 9, 24, 0, 0),
        endTime: DateTime(2024, 9, 24, 23, 59),
      );

      expect(dataPoints.length, 1);
      final hdp = dataPoints.first;
      expect(hdp.type, HealthDataType.WORKOUT_ROUTE);
      expect(hdp.metadata, {'route_point_count': 2, 'workout_uuid': 'test-workout-uuid'});
      expect(hdp.value, isA<WorkoutRouteHealthValue>());

      final routeValue = hdp.value as WorkoutRouteHealthValue;
      expect(routeValue.locations.length, 2);
      expect(routeValue.workoutUuid, 'test-workout-uuid');
      final firstLocation = routeValue.locations.first;
      expect(firstLocation.latitude, 37.3349);
      expect(firstLocation.longitude, -122.00902);
      expect(firstLocation.speedAccuracy, 0.5);
      expect(firstLocation.courseAccuracy, 5.0);
    });
  });

  group('Workout route APIs', () {
    final health = Health(deviceInfo: MockDeviceInfoPlugin());

    setUpAll(() async {
      await health.configure();
    });

    test('startWorkoutRoute returns builder identifier', () async {
      final builderId = await health.startWorkoutRoute();
      expect(builderId, 'builder-123');
      expect(mockChannel.lastMethod, 'startWorkoutRoute');
      expect(mockChannel.lastArguments, isNull);
    });

    test('insertWorkoutRouteData serializes locations correctly', () async {
      final builderId = 'builder-123';
      final start = DateTime(2024, 9, 24, 12, 0).toLocal();
      final locations = [
        WorkoutRouteLocation(
          latitude: 37.0,
          longitude: -122.0,
          timestamp: start,
          altitude: 15,
          horizontalAccuracy: 5,
          verticalAccuracy: 8,
          speed: 1.5,
          course: 180,
          speedAccuracy: 0.5,
          courseAccuracy: 5,
        ),
      ];

      final success = await health.insertWorkoutRouteData(builderId: builderId, locations: locations);

      expect(success, isTrue);
      expect(mockChannel.lastMethod, 'insertWorkoutRouteData');
      final args = Map<String, dynamic>.from(mockChannel.lastArguments as Map);
      expect(args['builderId'], builderId);
      expect(args['locations'], hasLength(1));
      final serialized = Map<String, dynamic>.from((args['locations'] as List).first as Map);
      expect(serialized['latitude'], 37.0);
      expect(serialized['longitude'], -122.0);
      expect(serialized['altitude'], 15);
      expect(serialized['horizontalAccuracy'], 5);
      expect(serialized['verticalAccuracy'], 8);
      expect(serialized['speed'], 1.5);
      expect(serialized['course'], 180);
      expect(serialized['speedAccuracy'], 0.5);
      expect(serialized['courseAccuracy'], 5);
      expect(serialized['timestamp'], start.toUtc().millisecondsSinceEpoch);
    });

    test('finishWorkoutRoute returns route uuid', () async {
      final routeUuid = await health.finishWorkoutRoute(
        builderId: 'builder-123',
        workoutUuid: 'workout-uuid-1',
        metadata: const {'note': 'example'},
      );

      expect(routeUuid, 'route-uuid-123');
      expect(mockChannel.lastMethod, 'finishWorkoutRoute');
      final args = Map<String, dynamic>.from(mockChannel.lastArguments as Map);
      expect(args['builderId'], 'builder-123');
      expect(args['workoutUUID'], 'workout-uuid-1');
      expect(args['metadata'], {'note': 'example'});
    });

    test('discardWorkoutRoute returns true', () async {
      final success = await health.discardWorkoutRoute('builder-123');

      expect(success, isTrue);
      expect(mockChannel.lastMethod, 'discardWorkoutRoute');
      final args = Map<String, dynamic>.from(mockChannel.lastArguments as Map);
      expect(args['builderId'], 'builder-123');
    });
  });
}
