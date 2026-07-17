import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';

/// A top-level grouping (Personal, Company A, …). `colorValue` is a 32-bit ARGB
/// int so the domain stays free of `dart:ui` (the UI converts it to a Color).
@freezed
abstract class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    required String shortCode,
    required int colorValue,
    @Default(false) bool isPersonal,
  }) = _Workspace;
}
