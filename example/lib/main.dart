import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/src/data_types.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carp_serializable/carp_serializable.dart';

part 'src/actions/changes.dart';
part 'src/actions/delete_data.dart';
part 'src/actions/health_connect_setup.dart';
part 'src/actions/permissions.dart';
part 'src/actions/read_data.dart';
part 'src/actions/skin_temperature.dart';
part 'src/actions/write_pool_swim.dart';
part 'src/actions/write_sample_data.dart';
part 'src/actions/write_single_records.dart';
part 'src/actions/write_workout_route.dart';
part 'src/app_state.dart';
part 'src/health_app_state.dart';
part 'src/widgets/action_buttons.dart';
part 'src/widgets/changes_list.dart';
part 'src/widgets/content.dart';
part 'src/widgets/detail_bottom_sheet.dart';
part 'src/widgets/health_data_list.dart';
part 'src/widgets/recording_method_filters.dart';

// Global Health instance
final health = Health();

void main() => runApp(HealthApp());

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  HealthAppState createState() => HealthAppState();
}
