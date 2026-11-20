import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  group('MetricTile', () {
    Widget tile({String? value, bool loading = false, String? error}) => designTestApp(
      SizedBox(
        width: 180,
        child: MetricTile(
          label: 'Heart rate',
          value: value,
          unit: 'bpm',
          icon: Icons.favorite,
          footnote: 'Latest',
          loading: loading,
          error: error,
        ),
      ),
    );

    testWidgets('shows the value with its unit', (tester) async {
      await tester.pumpWidget(tile(value: '72'));

      expect(find.text('72 bpm', findRichText: true), findsOneWidget);
      expect(find.text('Heart rate'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
    });

    testWidgets('shows a loading indicator, then the value', (tester) async {
      ExpressiveShape iconShape() => tester.widget<ShapedIcon>(find.byType(ShapedIcon)).shape;
      await tester.pumpWidget(tile(loading: true));
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      expect(iconShape(), ExpressiveShape.circle);

      await tester.pumpWidget(tile(value: '72'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      expect(find.text('72 bpm', findRichText: true), findsOneWidget);
      expect(iconShape(), ExpressiveShape.cookie9, reason: 'the icon springs into its shape with the value');
    });

    testWidgets('shows an error instead of the value, and a dash without data', (tester) async {
      await tester.pumpWidget(tile(error: 'No permission'));
      expect(find.text('No permission'), findsOneWidget);

      await tester.pumpWidget(tile());
      await tester.pumpAndSettle();
      expect(find.text('—', findRichText: true), findsOneWidget);
    });
  });

  testWidgets('StatusPill and PlatformBadge show their labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      designTestApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(label: 'Granted', tone: StatusTone.success, icon: Icons.check),
            PlatformBadge.android(),
            PlatformBadge.ios(),
          ],
        ),
      ),
    );

    expect(find.text('Granted'), findsOneWidget);
    expect(find.bySemanticsLabel('Android only'), findsOneWidget);
    expect(find.bySemanticsLabel('iOS only'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('EmptyState shows its title, message and action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      designTestApp(
        EmptyState(
          icon: Icons.inbox,
          title: 'No data',
          message: 'Nothing was recorded in this range.',
          action: FilledButton(onPressed: () => pressed = true, child: const Text('Try again')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('Nothing was recorded in this range.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(pressed, isTrue);
  });

  testWidgets('FloatingToolbar shows its actions', (tester) async {
    var sorted = false;
    await tester.pumpWidget(
      designTestApp(
        FloatingToolbar(
          children: [IconButton(tooltip: 'Sort', onPressed: () => sorted = true, icon: const Icon(Icons.sort))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sort'));
    expect(sorted, isTrue);
  });

  group('ExpressivePage', () {
    testWidgets('shows the title, content and floating action button, and the subtitle on demand', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ExpressiveTheme.light(),
          home: ExpressivePage(
            title: 'Overview',
            subtitle: 'Your data at a glance',
            slivers: const [SliverToBoxAdapter(child: Text('Content'))],
            floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
          ),
        ),
      );

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // The subtitle stays off the page until its info button is tapped.
      expect(find.text('Your data at a glance'), findsNothing);
      await tester.tap(find.byTooltip('About Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Your data at a glance'), findsOneWidget);
    });

    testWidgets('refreshes on pull with the expressive indicator', (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ExpressiveTheme.light(),
          home: ExpressivePage(
            title: 'Overview',
            onRefresh: () async => refreshes++,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 200, child: Text('Content')))],
          ),
        ),
      );

      await tester.fling(find.text('Content'), const Offset(0, 400), 1000);
      await tester.pump();
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshes, 1);
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    });

    testWidgets('keeps the content column readable on wide windows', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ExpressiveTheme.light(),
          home: const ExpressivePage(
            title: 'Overview',
            slivers: [SliverToBoxAdapter(child: SizedBox(height: 50, child: Placeholder()))],
          ),
        ),
      );

      expect(tester.getSize(find.byType(Placeholder)).width, ExpressivePage.maxContentWidth);
      expect(tester.getTopLeft(find.byType(Placeholder)).dx, (1400 - ExpressivePage.maxContentWidth) / 2);
    });
  });
}
