import '../../../../core/error/result.dart';

/// Whether the chat info panel rests beside an open chat on this device.
abstract class ChatInfoPanelPreference {
  /// True until the user hides the panel.
  Future<Result<bool>> isVisible();

  Future<Result<void>> setVisible(bool visible);
}
