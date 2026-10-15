import '../../error/result.dart';
import 'provider_adapter.dart';

abstract interface class ZenTaoMessagesAdapter implements ProviderAdapter {
  Future<Result<Map<String, dynamic>>> fetchMessages();

  Future<Result<void>> messageAction(String action);

  Future<Result<Map<String, dynamic>>> fetchUserInfo({
    required String fields,
    required int limit,
  });
}
