import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';

/// The people of a ZenTao product or execution, as ZenTao's own forms list
/// them: who a product's bugs may go to, and an execution's team.
abstract interface class ZenTaoTeamMembers {
  Future<Result<List<ProviderUser>>> productMembers(
    String accountId,
    String productId,
  );

  Future<Result<List<ProviderUser>>> executionMembers(
    String accountId,
    String executionId,
  );
}
