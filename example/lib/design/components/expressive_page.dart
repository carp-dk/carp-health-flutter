/// The frame of every page: a large collapsing app bar over a scrolling column of slivers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/expressive_typography.dart';
import 'expressive_refresh_indicator.dart';
import 'info_button.dart';

/// A page: a `Scaffold` with a collapsing `SliverAppBar.medium` showing the emphasized [title], toolbar
/// [actions] (plus an `InfoButton` when [subtitle] is given), the content [slivers], an optional
/// [floatingActionButton], and pull to refresh when [onRefresh] is given.
///
/// The slivers are laid out in a column with [gutter] side margins; on wide windows the column stays at
/// most [maxContentWidth] wide and centred, and the title moves in with it so they stay aligned. Space
/// is left under the last sliver so that the floating action button never covers it. Snack bars show on
/// this page's scaffold, above its floating action button.
class ExpressivePage extends StatelessWidget {
  /// Creates a page.
  const ExpressivePage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.slivers,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.onRefresh,
  });

  /// The page's name, large at the top and in the toolbar once collapsed.
  final String title;

  /// What the page does, opened from the info button in the app bar.
  final String? subtitle;

  /// Icon buttons at the end of the toolbar.
  final List<Widget>? actions;

  /// The content.
  final List<Widget> slivers;

  /// A floating action button (or `FabMenu`).
  final Widget? floatingActionButton;

  /// Where [floatingActionButton] sits; the bottom end by default. A `FloatingToolbar` goes centred, with
  /// `FloatingActionButtonLocation.centerFloat`.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Reloads the page's data on pull to refresh; null turns pull to refresh off.
  final Future<void> Function()? onRefresh;

  /// The widest the content column gets.
  static const double maxContentWidth = 840;

  /// The space between the content and the sides of the window.
  static const double gutter = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(gutter, (constraints.maxWidth - maxContentWidth) / 2);
          // The app bar already insets its title and actions by the gutter.
          final barInset = side - gutter;
          final scrollView = CustomScrollView(
            // Pull to refresh needs a scrollable page even when the content is short.
            physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar.medium(
                title: Padding(
                  padding: EdgeInsetsDirectional.only(start: barInset),
                  // Merges into both the expanded and collapsed styles, emphasizing either.
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: ExpressiveTypography.heavier(theme.textTheme.headlineSmall!.fontWeight!),
                      letterSpacing: -0.25,
                    ),
                  ),
                ),
                actions: [
                  ...?actions,
                  if (subtitle case final subtitle?) InfoButton(title: title, message: subtitle),
                ],
                actionsPadding: EdgeInsetsDirectional.only(end: barInset + 4),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              for (final sliver in slivers)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: sliver,
                ),
              SliverToBoxAdapter(child: SizedBox(height: floatingActionButton == null ? 32 : 112)),
            ],
          );
          final refresh = onRefresh;
          return refresh == null ? scrollView : ExpressiveRefreshIndicator(onRefresh: refresh, child: scrollView);
        },
      ),
    );
  }
}
