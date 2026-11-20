/// The audiogram the Audiogram form edits: tested frequencies with each ear's hearing threshold, sample
/// audiograms, and the edits that keep it within what HealthKit accepts.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:health_example/core/format/formatters.dart';

/// An ear of an audiogram.
enum Ear {
  /// The left ear, drawn with crosses as on a clinical audiogram.
  left,

  /// The right ear, drawn with circles.
  right,
}

/// One tested frequency: the [frequency] in hertz and the hearing threshold of each ear in decibels
/// hearing level (dB HL), where lower is better and up to 20 dB HL counts as normal hearing.
@immutable
class AudiogramPoint {
  /// Creates the point at [frequency] with the [left] and [right] thresholds.
  const AudiogramPoint(this.frequency, {required this.left, required this.right});

  /// The frequency in Hz.
  final double frequency;

  /// The threshold of the left ear in dB HL.
  final double left;

  /// The threshold of the right ear in dB HL.
  final double right;

  /// The threshold of [ear].
  double of(Ear ear) => ear == Ear.left ? left : right;

  /// This point with [ear]'s threshold set to [value].
  AudiogramPoint withThreshold(Ear ear, double value) =>
      AudiogramPoint(frequency, left: ear == Ear.left ? value : left, right: ear == Ear.right ? value : right);

  @override
  bool operator ==(Object other) =>
      other is AudiogramPoint && other.frequency == frequency && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(frequency, left, right);

  @override
  String toString() => 'AudiogramPoint(${frequencyLabel(frequency)}, L $left, R $right)';
}

/// A sample audiogram to start from.
enum AudiogramPreset {
  /// Normal hearing: every threshold at most 15 dB HL.
  normal('Normal', [250, 500, 1000, 2000, 4000, 8000], [5, 5, 10, 5, 10, 15], [10, 5, 5, 10, 5, 10]),

  /// Age-related hearing loss: thresholds that slope down towards the high frequencies.
  sloping('Age-related', [250, 500, 1000, 2000, 4000, 8000], [10, 10, 15, 25, 45, 60], [10, 15, 15, 30, 50, 65]),

  /// Noise-induced hearing loss: a dip around 4 kHz that recovers at 8 kHz.
  notch('Noise notch', [250, 500, 1000, 2000, 3000, 4000, 6000, 8000], [10, 10, 10, 15, 30, 45, 35, 20], [
    5,
    10,
    10,
    15,
    35,
    50,
    40,
    20,
  ]);

  const AudiogramPreset(this.label, this._frequencies, this._left, this._right);

  /// The preset's name, such as "Age-related".
  final String label;

  final List<double> _frequencies;
  final List<double> _left;
  final List<double> _right;

  /// The preset's points, in ascending frequency.
  List<AudiogramPoint> get points => [
    for (var i = 0; i < _frequencies.length; i++) AudiogramPoint(_frequencies[i], left: _left[i], right: _right[i]),
  ];
}

/// The frequencies the form offers and the edits it makes, which keep the frequencies unique and in
/// ascending order and the thresholds within HealthKit's range, as `writeAudiogram` requires.
abstract final class AudiogramPlan {
  /// The frequencies of a pure-tone audiogram in Hz: the octaves from 125 Hz to 8 kHz and the half
  /// octaves that clinics also test. HealthKit accepts any frequency from 0 to 30,000 Hz.
  static const List<double> frequencies = [125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000];

  /// The lowest threshold HealthKit accepts, in dB HL.
  static const double minThreshold = -20;

  /// The highest threshold HealthKit accepts, in dB HL.
  static const double maxThreshold = 160;

  /// The step of a threshold, as audiometers test in 5 dB steps.
  static const double step = 5;

  /// The threshold up to which hearing counts as normal, in dB HL.
  static const double normalLimit = 20;

  /// [points] with [frequency] removed when it is tested, or added (in order) when it is not, with
  /// thresholds that follow from its neighbours ([interpolate]).
  static List<AudiogramPoint> toggle(List<AudiogramPoint> points, double frequency) {
    if (points.any((point) => point.frequency == frequency)) {
      return [
        for (final point in points)
          if (point.frequency != frequency) point,
      ];
    }
    final added = AudiogramPoint(
      frequency,
      left: interpolate(points, frequency, Ear.left),
      right: interpolate(points, frequency, Ear.right),
    );
    return [...points, added]..sort((a, b) => a.frequency.compareTo(b.frequency));
  }

  /// [points] with the threshold of [ear] at [frequency] set to [value], kept within HealthKit's range.
  static List<AudiogramPoint> setThreshold(List<AudiogramPoint> points, double frequency, Ear ear, double value) => [
    for (final point in points)
      point.frequency == frequency ? point.withThreshold(ear, value.clamp(minThreshold, maxThreshold)) : point,
  ];

  /// The threshold of [ear] at [frequency] read off the line through [points] (on a logarithmic frequency
  /// scale, as audiograms are drawn), rounded to a [step]; the nearest point's beyond the ends, and 20 dB HL
  /// without points.
  static double interpolate(List<AudiogramPoint> points, double frequency, Ear ear) {
    if (points.isEmpty) return normalLimit;
    final below = points.lastWhere((point) => point.frequency < frequency, orElse: () => points.first);
    final above = points.firstWhere((point) => point.frequency > frequency, orElse: () => points.last);
    if (below.frequency >= frequency || above.frequency == below.frequency) {
      return (frequency <= below.frequency ? below : above).of(ear);
    }
    final t = math.log(frequency / below.frequency) / math.log(above.frequency / below.frequency);
    final value = below.of(ear) + (above.of(ear) - below.of(ear)) * t;
    return (value / step).round() * step;
  }
}

/// [frequency] as an audiogram labels it, such as "500 Hz" or "1.5 kHz".
String frequencyLabel(double frequency) =>
    frequency >= 1000 ? '${formatNumber(frequency / 1000, maxDecimals: 1)} kHz' : '${formatNumber(frequency)} Hz';
