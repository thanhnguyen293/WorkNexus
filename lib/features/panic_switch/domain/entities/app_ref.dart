import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_ref.freezed.dart';

/// An app on this computer the switch can bring forward or hide. [id] is what
/// the platform finds it by: a bundle id on macOS, an executable path on
/// Windows, a desktop entry id on Linux.
@freezed
abstract class AppRef with _$AppRef {
  const factory AppRef({required String id, required String name}) = _AppRef;
}
