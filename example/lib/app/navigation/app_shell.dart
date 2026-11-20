/// The adaptive app shell: the top-level destinations with a navigation bar on phones and a navigation
/// rail on larger windows.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/insights/insights_page.dart';
import 'package:health_example/features/overview/overview_page.dart';
import 'package:health_example/features/read/read_page.dart';
import 'package:health_example/features/setup/setup_page.dart';
import 'package:health_example/features/write/write_page.dart';

import 'app_destination.dart';
import 'app_navigation.dart';
import 'destination_stack.dart';

/// The top level of the app: the page of the selected [AppDestination] (see [AppNavigation]) with the
/// navigation between destinations.
///
/// Compact windows (narrower than [railBreakpoint]) get a bottom `NavigationBar`; wider ones a
/// `NavigationRail`, extended with labels beside the icons from [extendedRailBreakpoint]. Every
/// destination keeps its state ([DestinationStack]). Selecting the current destination again scrolls its
/// page to the top, and the back gesture on another destination returns to the overview first.
///
/// The shell has no `Scaffold` of its own on purpose: each page's `Scaffold` (see `ExpressivePage`) is
/// then a top-level one, so snack bars appear on the page, above its floating action button.
class AppShell extends StatefulWidget {
  /// Creates the shell; [pageBuilder] builds each destination's page ([defaultPage] unless replaced, for
  /// example by tests).
  const AppShell({super.key, this.pageBuilder = defaultPage});

  /// Builds the page of a destination.
  final Widget Function(AppDestination destination) pageBuilder;

  /// The window width (dp) from which a navigation rail replaces the navigation bar: Material's medium
  /// window size class.
  static const double railBreakpoint = 600;

  /// The window width (dp) from which the rail shows its labels beside the icons.
  static const double extendedRailBreakpoint = 1000;

  /// The page of each destination: the features of the app.
  static Widget defaultPage(AppDestination destination) => switch (destination) {
    AppDestination.overview => const OverviewPage(),
    AppDestination.read => const ReadPage(),
    AppDestination.insights => const InsightsPage(),
    AppDestination.write => const WritePage(),
    AppDestination.setup => const SetupPage(),
  };

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Map<AppDestination, ScrollController> _scrollControllers = {
    for (final destination in AppDestination.values) destination: ScrollController(),
  };

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(AppDestination destination, AppDestination current) {
    if (destination != current) {
      AppNavigation.goTo(context, destination);
      return;
    }
    final controller = _scrollControllers[destination]!;
    if (controller.hasClients) {
      // A critically damped spring: a scroll position must not overshoot the top.
      const motion = ExpressiveMotion.effectsSlow;
      controller.animateTo(0, duration: motion.duration, curve: motion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = AppNavigation.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final pages = DestinationStack(
      current: current,
      pageBuilder: widget.pageBuilder,
      scrollControllers: _scrollControllers,
    );
    void onSelected(int index) => _select(AppDestination.values[index], current);

    final Widget shell;
    if (width < AppShell.railBreakpoint) {
      shell = Column(
        children: [
          // The navigation bar covers the bottom inset (it pads itself), so the pages must not.
          Expanded(
            child: MediaQuery.removePadding(context: context, removeBottom: true, child: pages),
          ),
          // The shell has no outer Scaffold, so remove the top status bar inset from the bottom bar.
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: NavigationBar(
              selectedIndex: current.index,
              onDestinationSelected: onSelected,
              destinations: [
                for (final destination in AppDestination.values)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      final extended = width >= AppShell.extendedRailBreakpoint;
      // The rail sits at the start: on the right in right-to-left layouts.
      final rtl = Directionality.of(context) == TextDirection.rtl;
      shell = Row(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeLeft: rtl,
            removeRight: !rtl,
            child: NavigationRail(
              selectedIndex: current.index,
              onDestinationSelected: onSelected,
              extended: extended,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: ShapedIcon(icon: Icons.favorite, shape: ExpressiveShape.cookie9),
              ),
              destinations: [
                for (final destination in AppDestination.values)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          // The rail covers the inset on its side (it pads itself), so the pages must not.
          Expanded(
            child: MediaQuery.removePadding(context: context, removeLeft: !rtl, removeRight: rtl, child: pages),
          ),
        ],
      );
    }

    return PopScope(
      // Back on another destination returns to the overview before it leaves the app.
      canPop: current == AppDestination.overview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppNavigation.goTo(context, AppDestination.overview);
      },
      child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: shell),
    );
  }
}
