import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/chat_info_panel_preference.dart';

final chatInfoPanelPreferenceProvider = Provider<ChatInfoPanelPreference>(
  (ref) => getIt<ChatInfoPanelPreference>(),
);

/// Whether the user keeps the chat info panel beside the chat (when the
/// window has room for it). Kept for the app's lifetime and on this device.
class ChatInfoPanelVisibility extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      // Unreadable, the panel shows as it did before it could be hidden.
      (await ref.read(chatInfoPanelPreferenceProvider).isVisible())
          .valueOrNull ??
      true;

  /// Shows or hides the panel at once, then saves the choice. A failed save
  /// keeps the choice for this run and is returned for the caller to report.
  Future<Result<void>> setVisible(bool visible) {
    state = AsyncData(visible);
    return ref.read(chatInfoPanelPreferenceProvider).setVisible(visible);
  }
}

final chatInfoPanelVisibleProvider =
    AsyncNotifierProvider<ChatInfoPanelVisibility, bool>(
      ChatInfoPanelVisibility.new,
    );
