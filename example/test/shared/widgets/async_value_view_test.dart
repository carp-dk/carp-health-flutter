import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../support/shared_test_app.dart';

/// A HealthPlatformException with the native [code], as Health Connect or HealthKit reports it.
HealthPlatformException _platformError(String code, String message) =>
    HealthPlatformException(HealthDataType.STEPS, PlatformException(code: code, message: message));

void main() {
  group('AsyncValueView', () {
    Widget view(AsyncValue<int> value, {VoidCallback? onRetry}) => sharedTestApp(
      AsyncValueView<int>(
        value: value,
        data: (context, steps) => Text('$steps steps'),
        idle: const Text('Not read yet'),
        loadingLabel: 'Reading steps…',
        onRetry: onRetry,
      ),
      scrollable: true,
    );

    testWidgets('shows the idle widget, then a loading indicator with its label', (tester) async {
      await tester.pumpWidget(view(const AsyncIdle()));
      expect(find.text('Not read yet'), findsOneWidget);

      await tester.pumpWidget(view(const AsyncLoading()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      expect(find.text('Reading steps…'), findsOneWidget);
    });

    testWidgets('shows the data, and keeps it under a progress bar while it refreshes', (tester) async {
      await tester.pumpWidget(view(const AsyncData(1234)));
      await tester.pumpAndSettle();
      expect(find.text('1234 steps'), findsOneWidget);
      expect(find.byType(WavyProgressIndicator), findsNothing);

      await tester.pumpWidget(view(const AsyncLoading(previous: 1234)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('1234 steps'), findsOneWidget);
      expect(find.byType(WavyProgressIndicator), findsOneWidget);
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    });

    testWidgets('shows an error in an error card that retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(view(AsyncError(StateError('No steps'), StackTrace.empty), onRetry: () => retries++));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorCard), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });

  group('ErrorCard', () {
    testWidgets('explains a plugin error: title, message, advice and codes', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        sharedTestApp(
          ErrorCard(error: _platformError('RATE_LIMIT_EXCEEDED', 'Quota used up'), onRetry: () => retries++),
          scrollable: true,
        ),
      );

      expect(find.text('Rate limit reached'), findsOneWidget);
      expect(find.text('Quota used up'), findsOneWidget);
      expect(find.text('rateLimitExceeded · RATE_LIMIT_EXCEEDED'), findsOneWidget);
      // The error is retryable, so retrying is the emphasized action.
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);

      // Advice lives in the error details dialog.
      await tester.tap(find.byTooltip('Details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('try again later'), findsOneWidget);
    });

    testWidgets('offers a quieter retry for errors that will not go away by themselves', (tester) async {
      await tester.pumpWidget(sharedTestApp(ErrorCard(error: ArgumentError('Bad unit'), onRetry: () {})));

      expect(find.text('Invalid argument'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
    });

    testWidgets('links a permission error to Setup', (tester) async {
      final destination = ValueNotifier(AppDestination.read);
      addTearDown(destination.dispose);
      await tester.pumpWidget(
        sharedTestApp(
          ErrorCard(error: _platformError('PERMISSION_DENIED', 'No READ_STEPS')),
          destination: destination,
          scrollable: true,
        ),
      );

      expect(find.text('Permission needed'), findsOneWidget);
      await tester.tap(find.text('Open Setup'));
      expect(destination.value, AppDestination.setup);
    });

    testWidgets('has no buttons without a retry or a way to Setup', (tester) async {
      await tester.pumpWidget(sharedTestApp(ErrorCard(error: _platformError('PERMISSION_DENIED', 'No READ_STEPS'))));

      expect(find.text('Open Setup'), findsNothing, reason: 'no AppNavigation above it');
      expect(find.text('Try again'), findsNothing);
    });
  });
}
