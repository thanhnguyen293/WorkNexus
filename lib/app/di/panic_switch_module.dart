import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../core/database/app_settings_kv_store.dart';
import '../../core/database/database.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/panic_switch/data/datasources/panic_switch_channel.dart';
import '../../features/panic_switch/data/datasources/panic_switch_settings_store.dart';
import '../../features/panic_switch/data/repositories/asset_panic_sticker_source.dart';
import '../../features/panic_switch/data/repositories/channel_app_switcher.dart';
import '../../features/panic_switch/data/repositories/channel_panic_overlay.dart';
import '../../features/panic_switch/data/repositories/linux_app_switcher.dart';
import '../../features/panic_switch/data/repositories/local_panic_switch_config_repository.dart';
import '../../features/panic_switch/domain/repositories/app_switcher.dart';
import '../../features/panic_switch/domain/repositories/panic_chat_gateway.dart';
import '../../features/panic_switch/domain/repositories/panic_overlay.dart';
import '../../features/panic_switch/domain/repositories/panic_sticker_source.dart';
import '../../features/panic_switch/domain/repositories/panic_switch_config_repository.dart';
import '../../features/panic_switch/domain/usecases/run_panic_switch.dart';
import '../../features/panic_switch/domain/usecases/send_panic_sticker.dart';
import 'chat_panic_chat_gateway.dart';

/// Wiring for the panic switch, kept out of the main composition root
/// (`service_locator.dart`) so that file stays within its size budget.
@module
abstract class PanicSwitchModule {
  @lazySingleton
  PanicSwitchChannel get panicSwitchChannel => PanicSwitchChannel();

  @lazySingleton
  PanicSwitchConfigRepository panicSwitchConfigRepository(AppDatabase db) =>
      LocalPanicSwitchConfigRepository(
        PanicSwitchSettingsStore(AppSettingsKvStore(db)),
      );

  @lazySingleton
  AppSwitcher appSwitcher(PanicSwitchChannel channel) =>
      Platform.isLinux ? const LinuxAppSwitcher() : ChannelAppSwitcher(channel);

  @lazySingleton
  PanicOverlay panicOverlay(PanicSwitchChannel channel) =>
      ChannelPanicOverlay(channel);

  @lazySingleton
  PanicStickerSource get panicStickerSource =>
      AssetPanicStickerSource(rootBundle);

  @lazySingleton
  PanicChatGateway panicChatGateway(ChatRepository chats) =>
      ChatPanicChatGateway(chats);

  @lazySingleton
  SendPanicSticker sendPanicSticker(
    PanicChatGateway chats,
    PanicStickerSource sticker,
  ) => SendPanicSticker(chats, sticker);

  @lazySingleton
  RunPanicSwitch runPanicSwitch(AppSwitcher apps) => RunPanicSwitch(apps);
}
