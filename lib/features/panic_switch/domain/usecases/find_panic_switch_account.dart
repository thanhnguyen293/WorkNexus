import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../panic_switch_constants.dart';

/// The ZenTao account the panic switch works through, or null when the user
/// is not signed in to the ZenTao it is offered for — then the feature is off.
class FindPanicSwitchAccount {
  const FindPanicSwitchAccount();

  Account? call(List<Account> accounts) {
    final wanted = _normalize(PanicSwitchConstants.zentaoBaseUrl);
    for (final account in accounts) {
      final url = account.baseUrl;
      if (account.providerType == ProviderType.zentao &&
          url != null &&
          _normalize(url) == wanted) {
        return account;
      }
    }
    return null;
  }

  // Users type the URL with or without a trailing slash, in any case.
  static String _normalize(String url) =>
      url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
}
