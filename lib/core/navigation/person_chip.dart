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
