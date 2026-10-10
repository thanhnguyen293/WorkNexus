import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Draws a ZenTao person (avatar + [name]) of account [accountId]; [name] is
/// their display name or login handle.
typedef PersonChipBuilder =
    Widget Function(
      BuildContext context, {
      required String accountId,
      required String name,
      required double avatarSize,
    });

/// The chat-aware person chip (photo, "verified" check, tap to chat), which
/// the app wires in from the chat feature so a ticket screen can show one
/// without importing chat. Null (tests, no chat) means a plain avatar.
final personChipBuilderProvider = Provider<PersonChipBuilder?>((ref) => null);

/// Draws just a ZenTao person's avatar (no name, no tap) at [diameter] — for a
/// spot that has its own tap target, like a board card.
typedef PersonAvatarBuilder =
    Widget Function(
      BuildContext context, {
      required String accountId,
      required String name,
      required double diameter,
    });

/// The person's chat photo, wired in from the chat feature like
/// [personChipBuilderProvider]. Null means an initial-letter avatar.
final personAvatarBuilderProvider = Provider<PersonAvatarBuilder?>(
  (ref) => null,
);
