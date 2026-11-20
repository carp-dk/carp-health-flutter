/// Formatting of dates, times, durations, numbers and enum names for display.
///
/// The example has no `intl` dependency, so these use a fixed English, 24-hour format. Every
/// function takes local or UTC times and shows them in local time; the ones that compare with the
/// current time take an optional `now` for tests.
library;

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The time of day of [value], such as "07:05", or "07:05:09" [withSeconds].
String formatTime(DateTime value, {bool withSeconds = false}) {
  final time = value.toLocal();
  final hoursAndMinutes = '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  return withSeconds ? '$hoursAndMinutes:${_twoDigits(time.second)}' : hoursAndMinutes;
}

/// The date of [value], such as "16 Nov", with the year when it is not the year of [now] or
/// [withYear] asks for it, such as "16 Nov 2025".
String formatDate(DateTime value, {DateTime? now, bool withYear = false}) {
  final date = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final dayAndMonth = '${date.day} ${_months[date.month - 1]}';
  return date.year == current.year && !withYear ? dayAndMonth : '$dayAndMonth ${date.year}';
}

/// The date and time of [value], such as "Today, 07:05", "Yesterday, 23:10" or "12 Nov, 14:00".
String formatDateTime(DateTime value, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  return '${_dayLabel(value.toLocal(), current)}, ${formatTime(value)}';
}

/// The range from [from] to [to], with the day once when both are on the same day, such as
/// "Today, 07:00 – 07:30", and in full otherwise.
String formatTimeRange(DateTime from, DateTime to, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final start = from.toLocal();
  final end = to.toLocal();
  if (start.isAtSameMomentAs(end)) return formatDateTime(start, now: current);
  if (_calendarDaysBetween(start, end) == 0) {
    return '${_dayLabel(start, current)}, ${formatTime(start)} – ${formatTime(end)}';
  }
  return '${formatDateTime(start, now: current)} – ${formatDateTime(end, now: current)}';
}

/// The short weekday name of [value], such as "Mon".
String formatWeekday(DateTime value) => _weekdays[value.toLocal().weekday - 1];

/// [duration] in its two largest units, such as "7 h 32 min", "45 min", "1 min 30 s" or
/// "250 ms" below a second.
String formatDuration(Duration duration) {
  if (duration.isNegative) return '-${formatDuration(-duration)}';
  if (duration == Duration.zero) return '0 s';
  if (duration < const Duration(seconds: 1)) return '${duration.inMilliseconds} ms';
  String pair(int major, String majorUnit, int minor, String minorUnit) =>
      minor == 0 ? '$major $majorUnit' : '$major $majorUnit $minor $minorUnit';
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  if (duration.inDays > 0) return pair(duration.inDays, 'd', hours, 'h');
  if (duration.inHours > 0) return pair(duration.inHours, 'h', minutes, 'min');
  if (duration.inMinutes > 0) return pair(duration.inMinutes, 'min', duration.inSeconds % 60, 's');
  return '${duration.inSeconds} s';
}

/// [value] with at most [maxDecimals] decimals, trailing zeros removed and thousands grouped,
/// such as "12,345.6". NaN shows as "–".
String formatNumber(num value, {int maxDecimals = 2}) {
  if (value.isNaN) return '–';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  final fixed = value.toDouble().toStringAsFixed(maxDecimals.clamp(0, 20));
  // toStringAsFixed switches to exponent notation from 1e21 on: show such values as they are.
  if (fixed.contains('e')) return value.toString();
  final negative = fixed.startsWith('-');
  final parts = (negative ? fixed.substring(1) : fixed).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  final text = fraction.isEmpty ? whole : '$whole.$fraction';
  // A small negative value that rounds to zero shows as "0", not "-0".
  return negative && text != '0' ? '-$text' : text;
}

/// How long ago [value] was, such as "just now", "5 min ago", "3 h ago", "yesterday" or
/// "4 days ago" (and "in 5 min" for the future); the date from a week on.
String formatRelative(DateTime value, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final time = value.toLocal();
  final difference = current.difference(time);
  final future = difference.isNegative;
  final span = difference.abs();
  String relative(String amount) => future ? 'in $amount' : '$amount ago';
  final days = _calendarDaysBetween(time, current);
  if (span < const Duration(minutes: 1)) return future ? 'in a moment' : 'just now';
  if (span < const Duration(hours: 1)) return relative('${span.inMinutes} min');
  if (span < const Duration(days: 1) || days == 0) return relative('${span.inHours} h');
  if (days == 1) return 'yesterday';
  if (days == -1) return 'tomorrow';
  if (days.abs() < 7) return relative('${days.abs()} days');
  return formatDate(time, now: current);
}

/// A code name in words: "HIGH_INTENSITY_INTERVAL_TRAINING" becomes
/// "High intensity interval training" and "motionPaused" becomes "Motion paused".
String humanize(String identifier) {
  final words = identifier
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

/// The name of an enum value in words, such as "Biking stationary" for
/// `HealthWorkoutActivityType.BIKING_STATIONARY`.
String formatEnumName(Enum value) => humanize(value.name);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "Today", "Yesterday", "Tomorrow" or the date of [value], seen from [now].
String _dayLabel(DateTime value, DateTime now) => switch (_calendarDaysBetween(value, now)) {
  0 => 'Today',
  1 => 'Yesterday',
  -1 => 'Tomorrow',
  _ => formatDate(value, now: now),
};

/// The calendar days from the day of [from] to the day of [to], each in its own time zone.
int _calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
