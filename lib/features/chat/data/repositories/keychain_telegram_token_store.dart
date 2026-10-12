import '../../../../core/platform/credential_store.dart';
import '../../domain/repositories/sticker_pack_source.dart';

/// The Telegram bot token, kept in the OS keychain beside the account
/// secrets.
class KeychainTelegramTokenStore implements TelegramTokenStore {
  const KeychainTelegramTokenStore(this._credentials);

  final CredentialStore _credentials;

  static const _ref = 'telegram:bot-token';

  @override
  Future<String?> read() => _credentials.read(_ref);

  @override
  Future<void> write(String token) => _credentials.write(_ref, token.trim());
}
