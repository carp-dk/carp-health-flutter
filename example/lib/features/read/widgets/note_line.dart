/// A short status line in a card of the Read page.
library;

import 'package:flutter/material.dart';

/// An [icon] before a short [text] that states something the plugin reported, such as a cancelled read or
/// changes that could not be applied. The card's info button explains it.
class NoteLine extends StatelessWidget {
  /// Creates a note.
  const NoteLine({super.key, required this.icon, required this.text});

  /// What kind of note it is.
  final IconData icon;

  /// What happened, in a few words.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Icon(icon, size: 20),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
