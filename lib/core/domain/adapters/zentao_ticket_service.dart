import '../../error/result.dart';
import 'provider_adapter.dart';

/// Loads a single ZenTao ticket on demand, or syncs ZenTao products/projects/executions.
abstract interface class ZenTaoTicketService {
  /// Fetches bug/task/story [id] of type [type] from the connected ZenTao
  /// account on [host], stores it and returns its WorkNexus ticket id.
  Future<Result<String>> fetchZenTaoTicket({
    String? accountId,
    required String host,
    required String type,
    required String id,
  });

  Future<Result<List<ProviderProduct>>> listProducts(String accountId);

  Future<List<ProviderProduct>?> cachedProducts(String accountId);

  Future<Result<List<ProviderProject>>> listProjects(String accountId);

  Future<List<ProviderProject>?> cachedProjects(String accountId);

  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  );

  Future<Result<Map<String, dynamic>>> fetchZenTaoMessages(String accountId);

  Future<Result<void>> zenTaoMessageAction(String accountId, String action);

  Future<Result<Map<String, dynamic>>> fetchZenTaoUserInfo(
    String accountId, {
    required String fields,
    required int limit,
  });
}
