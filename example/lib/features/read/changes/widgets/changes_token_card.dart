/// The card of Read > Changes that makes and shows the changes token.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../widgets/card_title.dart';
import '../changes_controller.dart';

/// The changes token: whether there is one and whether it expired, the token itself (tap to copy), the
/// types it follows and when it was made, and the button that makes a new one with `getChangesToken`.
class ChangesTokenCard extends StatelessWidget {
  /// Creates the card of [controller].
  const ChangesTokenCard({super.key, required this.controller});

  /// The Changes section's controller.
  final ChangesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final token = controller.token;
    final creating = controller.tokenRequest.isLoading;
    final (status, tone) = switch (token) {
      null => ('No token', StatusTone.neutral),
      _ when controller.tokenExpired => ('Expired', StatusTone.error),
      _ => ('Ready', StatusTone.success),
    };
    final muted = theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant);
    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            icon: Icons.key,
            shape: ExpressiveShape.pentagon,
            title: 'Changes token',
            trailing: StatusPill(label: status, tone: tone),
          ),
          const SizedBox(height: 14),
          if (token == null)
            Text('Create a token to track changes from now.', style: muted)
          else ...[
            _TokenText(token: token),
            const SizedBox(height: 8),
            Text(controller.tokenTypes.map((type) => type.label).join(', '), style: theme.textTheme.bodyMedium),
            Text(
              [
                if (controller.tokenCreatedAt case final made?) 'Created ${formatRelative(made)}',
                if (controller.lastSyncAt case final synced?) 'synced ${formatRelative(synced)}',
              ].join(' · '),
              style: muted,
            ),
            if (!controller.tokenFollowsSelection)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Selection changed — create a new token.', style: muted),
              ),
          ],
          if (controller.tokenRequest case AsyncError(:final error)) ...[
            const SizedBox(height: 14),
            ErrorCard(error: error, onRetry: controller.createToken),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: controller.canCreateToken ? controller.createToken : null,
            icon: creating
                ? const ExpressiveLoadingIndicator(size: 24, semanticsLabel: 'Creating token')
                : const Icon(Icons.add_link),
            label: Text(token == null ? 'Create token' : 'New token'),
          ),
        ],
      ),
    );
  }
}

/// The token in monospace, shortened to two lines; tapping copies it.
class _TokenText extends StatelessWidget {
  const _TokenText({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: ExpressiveShapes.rounded(ExpressiveShapes.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  token,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.monospace,
                ),
              ),
              Icon(Icons.copy, size: 18, color: scheme.onSurfaceVariant, semanticLabel: 'Copy the token'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Clipboard.setData(ClipboardData(text: token));
      messenger?.showSnackBar(const SnackBar(content: Text('Changes token copied')));
    } on PlatformException {
      messenger?.showSnackBar(const SnackBar(content: Text('Could not copy the token')));
    }
  }
}
