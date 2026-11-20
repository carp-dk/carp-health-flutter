/// Read: the plugin's reads of data points, in three sections that a connected button group switches
/// between.
///
/// * Query: `Health.getHealthDataFromTypes` (all at once, with `limit`, `preferredUnits` and
///   `recordingMethodsToFilter`), `Health.getHealthDataPages` (a lazy, cancellable stream of pages with
///   `pageSize` and, on Android, `readPermissionDenied`) and `Health.removeDuplicates`.
/// * Lookup: `Health.getHealthDataByUUID`, for one record, such as one this app just wrote.
/// * Changes (Android): `Health.getChangesToken` and `Health.getChanges`, applied to a local copy.
///
/// Each section has its own controller ([QueryController], [LookupController], [ChangesController]) that
/// makes the plugin calls; this page creates them and disposes of them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/health_connect_banner.dart';

import 'changes/changes_controller.dart';
import 'changes/changes_toolbar.dart';
import 'changes/changes_view.dart';
import 'lookup/lookup_controller.dart';
import 'lookup/lookup_view.dart';
import 'query/query_controller.dart';
import 'query/query_options.dart';
import 'query/query_toolbar.dart';
import 'query/query_view.dart';
import 'read_section.dart';
import 'widgets/read_section_picker.dart';
import 'widgets/section_entrance.dart';

/// The Read destination: a [ReadSectionPicker] (Query | Lookup | Changes) over the selected section, with
/// the section's floating toolbar, and a notice while Health Connect is not available.
///
/// The section controllers live as long as the page, which the app shell keeps alive, so a running read
/// goes on and every section keeps its results while the user looks at another section or destination.
/// Pull to refresh starts the section's action again: the read, the lookup or the sync.
class ReadPage extends StatefulWidget {
  /// Creates the Read page.
  const ReadPage({super.key, this.initialSection = ReadSection.query});

  /// The section shown first.
  final ReadSection initialSection;

  @override
  State<ReadPage> createState() => _ReadPageState();
}

/// Owns the three section controllers and the selected section.
class _ReadPageState extends State<ReadPage> {
  late final AppServices _services;
  late final QueryController _query;
  late final LookupController _lookup;
  late final ChangesController _changes;
  late ReadSection _section = widget.initialSection;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    final services = _services = AppScope.of(context);
    final health = services.health;
    final available = services.catalog.available;
    _query = QueryController(health: health, settings: services.settings, available: available);
    _lookup = LookupController(health: health, types: LookupController.typesFor(services.catalog));
    _changes = ChangesController(health: health, capabilities: services.capabilities, available: available);
  }

  @override
  void dispose() {
    _query.dispose();
    _lookup.dispose();
    _changes.dispose();
    super.dispose();
  }

  void _select(ReadSection section) {
    if (section != _section) setState(() => _section = section);
  }

  /// Opens Query set up to read [types] page by page: the full read that an expired changes token calls for.
  /// With no [types] (or while a read runs) Query opens as it was.
  void _readInQuery(Set<HealthDataType> types) {
    if (types.isNotEmpty && !_query.isReading) {
      _query.options = _query.options.copyWith(types: types, mode: QueryMode.pages);
    }
    _select(ReadSection.query);
  }

  /// Pull to refresh: starts the section's action again (each does nothing when it cannot run). Not
  /// awaited, so the refresh indicator hands over to the section's own progress at once, which for a page
  /// by page read includes its Cancel button.
  Future<void> _refresh() async {
    switch (_section) {
      case ReadSection.query:
        unawaited(_query.read());
      case ReadSection.lookup:
        unawaited(_lookup.lookUp());
      case ReadSection.changes:
        unawaited(_changes.fetchChanges());
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    const motion = ExpressiveMotion.effectsDefault;
    return ExpressivePage(
      title: 'Read',
      onRefresh: _refresh,
      // Always a widget, never null: the scaffold would otherwise spin a toolbar in as it does a FAB.
      floatingActionButton: AnimatedSwitcher(
        duration: motion.duration,
        switchInCurve: motion,
        switchOutCurve: motion,
        child: switch (_section) {
          ReadSection.query => QueryToolbar(key: const ValueKey(ReadSection.query), controller: _query),
          ReadSection.lookup => const SizedBox.shrink(key: ValueKey(ReadSection.lookup)),
          ReadSection.changes => ChangesToolbar(key: const ValueKey(ReadSection.changes), controller: _changes),
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      slivers: [
        SliverToBoxAdapter(
          child: ReadSectionPicker(selected: _section, onSelected: _select),
        ),
        SliverToBoxAdapter(
          child: HealthConnectBanner(capabilities: services.capabilities, padding: const EdgeInsets.only(top: 16)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SectionEntrance(
          section: _section,
          sliver: switch (_section) {
            ReadSection.query => QueryView(controller: _query, services: services),
            ReadSection.lookup => LookupView(controller: _lookup, services: services),
            ReadSection.changes => ChangesView(
              controller: _changes,
              catalog: services.catalog,
              onReadInQuery: _readInQuery,
            ),
          },
        ),
      ],
    );
  }
}
