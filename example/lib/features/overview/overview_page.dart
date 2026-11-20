/// The Overview feature: the health platform at a glance.
///
/// The hero card shows the platform and its status (`getHealthConnectSdkStatus` on Android), this
/// device's id (`Health.deviceId`) and access to the core data types (`hasPermissions` on Android,
/// `getRequestStatusForAuthorization` on iOS, `requestAuthorization` to grant it). The highlights read
/// today's steps (`getTotalStepsInInterval`), the latest heart rate and weight (`getHealthDataFromTypes`
/// with `limit: 1`), today's active energy and last night's sleep (`getHealthIntervalDataFromTypes`) and
/// this week's workouts (`getHealthDataFromTypes`), each on its own. On Android the page also lists
/// Health Connect's optional features (`isHealthDataHistoryAvailable`, `isSkinTemperatureAvailable`,
/// ...). [OverviewController] makes the calls.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';
import 'package:health_example/shared/widgets/health_connect_banner.dart';

import 'model/core_access.dart';
import 'model/highlight.dart';
import 'overview_controller.dart';
import 'widgets/feature_status_card.dart';
import 'widgets/highlights_grid.dart';
import 'widgets/platform_hero_card.dart';

/// The Overview destination: the hero card, the highlights and the Health Connect features, with
/// pull to refresh.
class OverviewPage extends StatefulWidget {
  /// Creates the overview page.
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final AppServices _services;
  late final OverviewController _controller;
  AppDestination? _shownAs;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    _services = AppScope.of(context);
    _controller = OverviewController(
      health: _services.health,
      capabilities: _services.capabilities,
      recentWrites: _services.recentWrites,
    )..load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps this page alive while another destination shows. When returning after a write
    // or delete, schedule the reload after build so listeners are never notified mid-build.
    final destination = context.dependOnInheritedWidgetOfExactType<AppNavigation>()?.notifier?.value;
    final returning = _shownAs != null && _shownAs != AppDestination.overview && destination == AppDestination.overview;
    _shownAs = destination;
    if (returning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.reloadIfStale();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Requests access (to [highlight]'s types, or all core types) from a tile or the menu, and says in
  /// a snack bar what `requestAuthorization` returned, as the hero card may be scrolled away.
  Future<void> _authorize([Highlight? highlight]) async {
    await _controller.authorize(highlight: highlight);
    if (!mounted) return;
    switch (_controller.authorization) {
      case AsyncError(:final error):
        showErrorSnackBar(context, error, message: 'requestAuthorization failed');
      case AsyncData(:final value):
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(CoreAccess.describeRequest(value, _controller.platform))));
      case AsyncIdle() || AsyncLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = _services.capabilities;
    const motion = ExpressiveMotion.spatialDefault;
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, capabilities]),
      builder: (context, _) => ExpressivePage(
        title: 'Overview',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _controller.refresh, icon: const Icon(Icons.refresh))],
        onRefresh: _controller.refresh,
        slivers: [
          SliverToBoxAdapter(child: PlatformHeroCard(controller: _controller)),
          SliverToBoxAdapter(
            child: HealthConnectBanner(capabilities: capabilities, padding: const EdgeInsets.only(top: 16)),
          ),
          if (_controller.canRead) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Highlights',
                trailing: AnimatedSwitcher(
                  duration: motion.duration,
                  switchInCurve: motion,
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: _controller.isLoading
                      ? const ExpressiveLoadingIndicator(size: 28, semanticsLabel: 'Reading highlights')
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: HighlightsGrid(controller: _controller, onAuthorize: _authorize),
            ),
          ],
          if (capabilities.isAndroid) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Features',
                trailing: TextButton(
                  onPressed: () => AppNavigation.goTo(context, AppDestination.setup),
                  child: const Text('Setup'),
                ),
              ),
            ),
            SliverToBoxAdapter(child: FeatureStatusCard(capabilities: capabilities)),
          ],
        ],
      ),
    );
  }
}
