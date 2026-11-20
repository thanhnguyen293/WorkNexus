import '../../error/result.dart';
import '../entities/account.dart';
import '../entities/person_profile.dart';

/// Looks up a colleague on the work tracker behind [Account] (ZenTao today).
/// Shared kernel: chat asks, the tracker answers, neither imports the other.
abstract class PersonDirectory {
  /// The profile of user [userId] (the tracker's user id) as [account] may
  /// see it.
  Future<Result<PersonProfile>> lookup(Account account, int userId);
}
