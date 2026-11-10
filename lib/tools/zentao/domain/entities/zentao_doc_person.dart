import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_doc_person.freezed.dart';

/// Someone who wrote or edited a ZenTao document: their login [account]
/// (unique, how chat finds them) and display [name] when ZenTao sent it.
@freezed
abstract class ZenTaoDocPerson with _$ZenTaoDocPerson {
  const ZenTaoDocPerson._();

  const factory ZenTaoDocPerson({required String account, String? name}) =
      _ZenTaoDocPerson;

  String get displayName => name ?? account;
}
