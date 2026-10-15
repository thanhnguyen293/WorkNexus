import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../entities/zentao_department.dart';
import '../entities/zentao_profile.dart';
import '../entities/zentao_profile_update.dart';

abstract class ZenTaoProfileRepository {
  Stream<ZenTaoProfile?> watch(String accountId);
  Stream<List<ZenTaoDepartment>> watchDepartments(String accountId);
  Future<Result<ZenTaoProfile>> refresh(Account account);
  Future<Result<ZenTaoProfile>> update(
    Account account,
    ZenTaoProfileUpdate changes,
  );
}
