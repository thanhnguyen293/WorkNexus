import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';

/// A project/product/repo within an [Account].
@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String accountId,
    required String name,
    String? externalId,
  }) = _Project;
}
