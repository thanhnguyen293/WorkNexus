import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_history_progress.freezed.dart';

/// How much of a chat's history is stored on this device while it
/// downloads: [stored] of [total] messages, until [complete].
@freezed
abstract class ChatHistoryProgress with _$ChatHistoryProgress {
  const ChatHistoryProgress._();

  const factory ChatHistoryProgress({
    required int stored,
    required int total,
    @Default(false) bool complete,
  }) = _ChatHistoryProgress;

  /// 0–1; null while the total is unknown.
  double? get fraction => complete
      ? 1
      : total > 0
      ? (stored / total).clamp(0, 1).toDouble()
      : null;
}
