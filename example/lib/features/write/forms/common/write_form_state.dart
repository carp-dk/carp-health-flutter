/// The state class of the Write page's own forms: it owns the form's controller and runs a write the way
/// every form does (check the fields, call the plugin, report the result).
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/shared/widgets/write_result.dart';

import 'write_form_controller.dart';

/// The [State] of a write form whose fields live in a [WriteFormController] of type [C].
///
/// It creates the controller from the app's services in [initState] ([createController]) and disposes
/// it with the form, wraps the fields ([buildFields]) in a `Form` and rebuilds them when the controller
/// changes. [write] is what the form's write button runs.
abstract class WriteFormState<W extends StatefulWidget, C extends WriteFormController> extends State<W> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// The form's controller, created by [createController].
  late final C controller;

  /// Creates the form's controller; [services] hold the plugin instance and the platform's capabilities.
  C createController(AppServices services);

  /// Builds the form's fields from [controller]; called again whenever it notifies.
  Widget buildFields(BuildContext context);

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    controller = createController(AppScope.of(context));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Checks the fields, writes with the controller and reports the result with `reportWriteResult`: a
  /// snack bar, with "View" when the write returned a UUID, and an entry in the recent writes when the
  /// data was saved. Whatever the plugin throws is reported, never rethrown.
  Future<void> write() async {
    // Empty or malformed numbers are caught by the fields, before the plugin is called.
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final result = await controller.write();
    if (!mounted) return;
    switch (result) {
      case AsyncData(value: final outcome):
        await reportWriteResult(
          context,
          type: outcome.type,
          description: outcome.description,
          success: outcome.success,
          uuid: outcome.uuid,
          clientRecordId: outcome.clientRecordId,
        );
      case AsyncError(:final error):
        await reportWriteResult(
          context,
          type: controller.type,
          description: controller.description,
          success: false,
          error: error,
        );
      case AsyncIdle() || AsyncLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: ListenableBuilder(listenable: controller, builder: (context, _) => buildFields(context)),
  );
}
