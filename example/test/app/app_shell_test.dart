import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/app/navigation/app_shell.dart';
import 'package:health_example/design/design.dart';

/// A stand-in page with state (a counter) and a long list that scrolls with the primary controller.
class _FakePage extends StatefulWidget {
  const _FakePage(this.destination);

  final AppDestination destination;

  @override
  State<_FakePage> createState() => _FakePageState();
}

class _FakePageState extends State<_FakePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        TextButton(onPressed: () => setState(() => _count++), child: Text('${widget.destination.name}: $_count')),
        for (var i = 0; i < 50; i++) SizedBox(height: 80, child: Text('${widget.destination.name} row $i')),
      ],
    ),
  );
}

void main() {
  late ValueNotifier<AppDestination> destination;
  late Set<AppDestination> built;

  setUp(() {
    destination = ValueNotifier(AppDestination.overview);
    built = {};
  });
  tearDown(() => destination.dispose());

  Future<void> pumpShell(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppNavigation(
        notifier: destination,
        child: MaterialApp(
          theme: ExpressiveTheme.light(),
          home: AppShell(
            pageBuilder: (page) {
              built.add(page);
              return _FakePage(page);
            },
          ),
        ),
      ),
    );
  }

  testWidgets('phones get a navigation bar that switches destinations', (tester) async {
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('overview: 0'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(destination.value, AppDestination.insights);
    expect(find.text('insights: 0'), findsOneWidget);
    expect(find.text('overview: 0'), findsNothing, reason: 'hidden pages are offstage');
  });

  testWidgets('builds a page when its destination is first shown and keeps its state', (tester) async {
    await pumpShell(tester);
    expect(built, {AppDestination.overview});

    await tester.tap(find.text('overview: 0'));
    await tester.pump();
    destination.value = AppDestination.setup;
    await tester.pumpAndSettle();
    expect(built, {AppDestination.overview, AppDestination.setup});

    destination.value = AppDestination.overview;
    await tester.pumpAndSettle();
    expect(find.text('overview: 1'), findsOneWidget);
  });

  testWidgets('wider windows get a navigation rail, extended on large ones', (tester) async {
    await pumpShell(tester, size: const Size(800, 800));
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isFalse);

    await pumpShell(tester, size: const Size(1200, 800));
    await tester.pumpAndSettle(); // the rail animates its extension
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);

    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(destination.value, AppDestination.write);
  });

  testWidgets('back returns to the overview before leaving the app', (tester) async {
    destination.value = AppDestination.read;
    await pumpShell(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(destination.value, AppDestination.overview);
  });

  testWidgets('goTo closes dialogs and sheets on top of the shell first', (tester) async {
    await pumpShell(tester);
    showDialog<void>(
      context: tester.element(find.text('overview: 0')),
      builder: (context) => TextButton(
        onPressed: () => AppNavigation.goTo(context, AppDestination.read),
        child: const Text('Go to Read'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Read'));
    await tester.pumpAndSettle();

    expect(find.text('Go to Read'), findsNothing);
    expect(destination.value, AppDestination.read);
    expect(find.text('read: 0'), findsOneWidget);
  });

  testWidgets('selecting the current destination again scrolls its page to the top', (tester) async {
    await pumpShell(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('overview: 0'), findsNothing);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('overview: 0'), findsOneWidget);
  });
}
