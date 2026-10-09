import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/zentao_profile.dart';
import '../entities/zentao_profile_update.dart';
import '../repositories/zentao_profile_repository.dart';

class UpdateZenTaoProfile {
  const UpdateZenTaoProfile(this._repository);

  final ZenTaoProfileRepository _repository;

  Future<Result<ZenTaoProfile>> call(
    Account account,
    ZenTaoProfileUpdate changes,
  ) {
    if (changes.realname.trim().isEmpty) {
      return Future.value(const Err(ParseFailure('Name is required')));
    }
    final email = changes.email.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return Future.value(const Err(ParseFailure('Invalid email address')));
    }
    return _repository.update(
      account,
      changes.copyWith(
        realname: changes.realname.trim(),
        email: email,
        mobile: changes.mobile.trim(),
        phone: changes.phone.trim(),
      ),
    );
  }
}
