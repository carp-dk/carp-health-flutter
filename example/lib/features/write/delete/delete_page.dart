/// Delete: removes data the app wrote, with `Health.delete` (the app's data of some types in a time
/// range) and, on Android, `Health.deleteByClientRecordId` (one record by the app's own id for it).
///
/// Records written with a UUID can also be deleted one by one with `Health.deleteByUUID`, from the Write
/// page's recent writes or the data point sheet. The [DeleteController] makes the calls.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';

import 'delete_by_client_id_card.dart';
import 'delete_by_range_card.dart';
import 'delete_controller.dart';

/// Opens the [DeletePage] over the current page.
Future<void> openDeletePage(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const DeletePage()));

/// The Delete page: the `delete` form ([DeleteByRangeCard]) and the `deleteByClientRecordId` form
/// ([DeleteByClientIdCard], marked Android only). That apps delete only their own data opens from the
/// page's info button.
class DeletePage extends StatefulWidget {
  /// Creates the page.
  const DeletePage({super.key});

  @override
  State<DeletePage> createState() => _DeletePageState();
}

/// Owns the page's [DeleteController].
class _DeletePageState extends State<DeletePage> {
  late final DeleteController _controller;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    final services = AppScope.of(context);
    _controller = DeleteController(
      health: services.health,
      capabilities: services.capabilities,
      catalog: services.catalog,
      recentWrites: services.recentWrites,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ExpressivePage(
      title: 'Delete data',
      slivers: [
        SliverToBoxAdapter(
          // The id field too: the delete button follows what is typed.
          child: ListenableBuilder(
            listenable: Listenable.merge([c, c.clientRecordId]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'By type and time'),
                DeleteByRangeCard(controller: c),
                const SectionHeader(title: 'By client record id', trailing: PlatformBadge.android()),
                DeleteByClientIdCard(controller: c),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
