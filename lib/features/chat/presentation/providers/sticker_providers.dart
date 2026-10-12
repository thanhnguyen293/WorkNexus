import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/repositories/sticker_pack_source.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../../domain/usecases/import_sticker_pack.dart';
import '../../domain/usecases/save_image_as_sticker.dart';
import '../../domain/usecases/send_sticker.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_providers.dart';

final stickerRepositoryProvider = Provider<StickerRepository>(
  (ref) => getIt<StickerRepository>(),
);

/// Every sticker: bundled sets, then the user's own.
final chatStickersProvider =
    FutureProvider.autoDispose<Result<List<ChatSticker>>>(
      (ref) => ref.watch(stickerRepositoryProvider).stickers(),
    );

/// The set the sticker panel opens on: the one last picked from. Kept for
/// the app's lifetime and on disk.
class LastStickerPackController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async =>
      (await ref.read(stickerRepositoryProvider).lastPack()).valueOrNull;

  /// Remembers [pack]; a failed write only means the panel opens elsewhere
  /// next launch, so it is not reported.
  void remember(String pack) {
    if (state.value == pack) return;
    state = AsyncData(pack);
    unawaited(ref.read(stickerRepositoryProvider).rememberPack(pack));
  }
}

final lastStickerPackProvider =
    AsyncNotifierProvider<LastStickerPackController, String?>(
      LastStickerPackController.new,
    );

final stickerPackSourceProvider = Provider<StickerPackSource>(
  (ref) => getIt<StickerPackSource>(),
);

final stickerConverterProvider = Provider<StickerConverter>(
  (ref) => getIt<StickerConverter>(),
);

final telegramTokenStoreProvider = Provider<TelegramTokenStore>(
  (ref) => getIt<TelegramTokenStore>(),
);

final stickerControllerProvider = Provider<StickerController>((ref) {
  final chats = ref.watch(chatRepositoryProvider);
  final stickers = ref.watch(stickerRepositoryProvider);
  return StickerController(
    stickers,
    sendSticker: SendSticker(chats, stickers),
    saveImage: SaveImageAsSticker(chats, stickers),
    onChanged: () => ref.invalidate(chatStickersProvider),
  );
});

/// Importing Telegram sets; built only when the import dialog asks for it.
final telegramStickerImporterProvider = Provider<TelegramStickerImporter>(
  (ref) => TelegramStickerImporter(
    ImportStickerPack(
      ref.watch(stickerPackSourceProvider),
      ref.watch(stickerConverterProvider),
      ref.watch(stickerRepositoryProvider),
    ),
    ref.watch(telegramTokenStoreProvider),
    onImported: () => ref.invalidate(chatStickersProvider),
  ),
);

/// Imports Telegram sticker sets, keeping the bot token that worked.
class TelegramStickerImporter {
  TelegramStickerImporter(
    this._importPack,
    this._tokens, {
    required void Function() onImported,
  }) : _onImported = onImported;

  final ImportStickerPack _importPack;
  final TelegramTokenStore _tokens;
  final void Function() _onImported;

  /// The bot token kept from a previous import, if any.
  Future<String?> savedToken() => _tokens.read();

  /// Imports the set at [link] with [token], which is kept for next time once
  /// it has worked.
  Future<Result<ImportedStickerPack>> import(
    String link, {
    required String token,
    void Function(String title, int total)? onListed,
    void Function(int done, int total)? onProgress,
  }) async {
    final result = await _importPack(
      link,
      token: token,
      onListed: onListed,
      onProgress: onProgress,
    );
    if (result is Ok) {
      await _tokens.write(token);
      _onImported();
    }
    return result;
  }
}

/// Sending stickers, keeping the user's own stickers and removing imported
/// sets.
class StickerController {
  StickerController(
    this._stickers, {
    required SendSticker sendSticker,
    required SaveImageAsSticker saveImage,
    required void Function() onChanged,
  }) : _sendSticker = sendSticker,
       _saveImage = saveImage,
       _onChanged = onChanged;

  final StickerRepository _stickers;
  final SendSticker _sendSticker;
  final SaveImageAsSticker _saveImage;
  final void Function() _onChanged;

  Future<Result<void>> removePack(String pack) =>
      _changed(_stickers.removePack(pack));

  Future<Result<void>> send(ChatThreadKey chat, ChatSticker sticker) =>
      _sendSticker(
        accountId: chat.accountId,
        chatGid: chat.chatGid,
        sticker: sticker,
      );

  /// Keeps a chat image (its original) as one of the user's stickers.
  Future<Result<void>> saveImage(String accountId, MessageContent image) =>
      _changed(_saveImage(accountId, image));

  Future<Result<void>> add(Uint8List bytes, String name) =>
      _changed(_stickers.add(bytes, name: name));

  Future<Result<void>> remove(ChatSticker sticker) =>
      _changed(_stickers.remove(sticker));

  Future<Result<void>> _changed<T>(Future<Result<T>> action) async {
    final result = await action;
    if (result is Ok) _onChanged();
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
