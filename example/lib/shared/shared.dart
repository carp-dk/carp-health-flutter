/// The domain widgets the features share, built on `core` (plugin logic) and `design` (Material 3
/// Expressive components). Import this one file to use any of them:
///
/// * showing plugin data: `DataPointTile`, `showDataPointSheet`, `DataPointDetails`, `TypedValueView`,
///   `openDataPointByUuid` (`getHealthDataByUUID`) and the texts and visuals they share;
/// * choosing what to read, write or delete: `showTypePicker`, `TypeChips`, `TimeRangeSelector` and
///   `RecordingMethodFilter`;
/// * writing: the form fields, `WriteButton` and `reportWriteResult`;
/// * the state of plugin calls: `AsyncValueView`, `ErrorCard` and the error snack bar and dialog.
library;

export 'data_point/data_point_details.dart';
export 'data_point/data_point_sheet.dart';
export 'data_point/data_point_text.dart';
export 'data_point/data_point_tile.dart';
export 'data_point/open_by_uuid.dart';
export 'data_point/value_views/typed_value_view.dart';
export 'visuals/monospace.dart';
export 'visuals/recording_method_visuals.dart';
export 'visuals/type_icon.dart';
export 'widgets/async_value_view.dart';
export 'widgets/error_card.dart';
export 'widgets/error_dialog.dart';
export 'widgets/form_fields.dart';
export 'widgets/recording_method_filter.dart';
export 'widgets/time_range_selector.dart';
export 'widgets/type_chips.dart';
export 'widgets/type_picker_sheet.dart';
export 'widgets/write_result.dart';
