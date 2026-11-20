/// The advice Read > Changes gives when Health Connect reports the changes token as expired.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Explains `HealthChangesResponse.changesTokenExpired` and how an app recovers from it: a full resync.
///
/// Health Connect expires a token that was not used for a long time, and the plugin also reports a token
/// as expired when the changes waiting are too many for Health Connect to return (or one change holds
/// more than 100,000 data points). Either way, changes were lost: the app makes a new token first, so
/// that nothing written from then on is missed, and reads the data again. [onNewToken] makes the token
/// (`getChangesToken`); [onReadInQuery] opens Query to read the token's types again page by page.
class TokenExpiredNotice extends StatelessWidget {
  /// Creates the notice.
  const TokenExpiredNotice({super.key, required this.onNewToken, required this.onReadInQuery});

  /// Makes a new token; null while that is not possible (a call runs, or no type is chosen).
  final VoidCallback? onNewToken;

  /// Opens Query set up to read the followed types again.
  final VoidCallback onReadInQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ExpressiveStatusColors.of(context);
    final text = theme.textTheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.error,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.largeIncreased),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 12,
                children: [
                  ShapedIcon(
                    icon: Icons.link_off,
                    shape: ExpressiveShape.sunny,
                    size: 40,
                    background: scheme.error,
                    foreground: scheme.onError,
                  ),
                  Expanded(
                    child: Text('Token expired', style: text.titleMediumEmphasized.copyWith(color: colors.onError)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new token and re-read in Query to resync.',
                style: text.bodyMedium!.copyWith(color: colors.onError),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                    onPressed: onNewToken,
                    icon: const Icon(Icons.add_link),
                    label: const Text('New token'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: colors.onError),
                    onPressed: onReadInQuery,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Read in Query'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
