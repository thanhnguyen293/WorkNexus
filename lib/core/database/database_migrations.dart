part of 'database.dart';

/// The schema migrations, kept apart from the table definitions and queries.
mixin _Migrations on _$AppDatabase {
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 33) await m.createTable(zenTaoProfiles);
      // from < 2: create the settings table at its *current* schema (which
      // already includes fontFamily), so skip the addColumn below.
      if (from < 2) {
        await m.createTable(settings);
      } else if (from < 3) {
        await m.addColumn(settings, settings.fontFamily);
      }
      if (from < 4) await m.createTable(activities);
      if (from < 5) await m.addColumn(tickets, tickets.providerEntityJson);
      if (from < 6) await m.addColumn(activities, activities.attachmentsJson);
      if (from < 7) await m.addColumn(settings, settings.componentRadius);
      if (from < 8) await m.addColumn(settings, settings.accentColorValue);
      if (from < 9) await m.addColumn(settings, settings.pinnedProjectsJson);
      if (from < 10) await m.addColumn(settings, settings.detailLayout);
      if (from < 11) await m.addColumn(settings, settings.dateFormat);
      if (from < 12) {
        await m.addColumn(settings, settings.pinnedExecutionsJson);
      }
      if (from < 13) {
        // Idempotent: a dev DB may already carry the column from a half-applied
        // migration (added, but the schema version not yet bumped). Skip then.
        if (!await _hasColumn('settings', 'sidebar_width')) {
          await m.addColumn(settings, settings.sidebarWidth);
        }
      }
      if (from < 14) {
        if (!await _hasColumn('settings', 'translation_lang')) {
          await m.addColumn(settings, settings.translationLang);
        }
      }
      if (from < 15) {
        if (!await _hasColumn('workspaces', 'icon_key')) {
          await m.addColumn(workspaces, workspaces.iconKey);
        }
      }
      if (from < 16) {
        if (!await _hasColumn('settings', 'translation_model')) {
          await m.addColumn(settings, settings.translationModel);
        }
        await m.createTable(savedFilters);
      }
      if (from < 17) {
        await m.createTable(chatAccounts);
        await m.createTable(chatConversations);
        await m.createTable(chatMessages);
        // Tables use IF NOT EXISTS; the index does not. Guarded because the
        // same DB file can be reopened after an older build has lowered its
        // version (e.g. running another branch), re-running this step.
        if (!await _hasIndex('chat_messages_by_chat')) {
          await m.createIndex(chatMessagesByChat);
        }
        await m.createTable(chatUsers);
      }
      if (from < 18) {
        if (!await _hasColumn('chat_messages', 'reply_to_id')) {
          await m.addColumn(chatMessages, chatMessages.replyToId);
        }
      }
      if (from < 19) {
        if (!await _hasColumn('settings', 'chat_appearance')) {
          await m.addColumn(settings, settings.chatAppearance);
        }
        if (!await _hasColumn('settings', 'chat_send_markdown')) {
          await m.addColumn(settings, settings.chatSendMarkdown);
        }
      }
      if (from < 20) {
        if (!await _hasColumn('settings', 'chat_notifications')) {
          await m.addColumn(settings, settings.chatNotifications);
        }
      }
      if (from < 21) {
        for (final (column, add) in [
          ('pinned_json', chatConversations.pinnedJson),
          ('owned_by', chatConversations.ownedBy),
          ('created_at', chatConversations.createdAt),
        ]) {
          if (!await _hasColumn('chat_conversations', column)) {
            await m.addColumn(chatConversations, add);
          }
        }
        for (final (column, add) in [
          ('email', chatUsers.email),
          ('mobile', chatUsers.mobile),
          ('phone', chatUsers.phone),
          ('role', chatUsers.role),
        ]) {
          if (!await _hasColumn('chat_users', column)) {
            await m.addColumn(chatUsers, add);
          }
        }
      }
      if (from < 35) {
        if (!await _hasColumn('settings', 'chat_text_scale')) {
          await m.addColumn(settings, settings.chatTextScale);
        }
      }
      if (from < 34) {
        if (!await _hasColumn('chat_conversations', 'committers')) {
          await m.addColumn(chatConversations, chatConversations.committers);
        }
      }
      if (from < 33) {
        if (!await _hasColumn('settings', 'chat_notify_while_viewing')) {
          await m.addColumn(settings, settings.chatNotifyWhileViewing);
        }
      }
      if (from < 32) {
        if (!await _hasColumn('settings', 'chat_auto_download_videos')) {
          await m.addColumn(settings, settings.chatAutoDownloadVideos);
        }
        if (!await _hasColumn('settings', 'chat_auto_download_video_mb')) {
          await m.addColumn(settings, settings.chatAutoDownloadVideoMb);
        }
      }
      if (from < 31) {
        await m.createTable(chatMessageTranslations);
        // Dev DBs already at 30 have the table without this column.
        if (!await _hasColumn('chat_message_translations', 'visible')) {
          await m.addColumn(
            chatMessageTranslations,
            chatMessageTranslations.visible,
          );
        }
      }
      if (from < 29) {
        if (!await _hasColumn('chat_conversations', 'muted')) {
          await m.addColumn(chatConversations, chatConversations.muted);
        }
      }
      if (from < 28) {
        if (!await _hasColumn('chat_conversations', 'starred')) {
          await m.addColumn(chatConversations, chatConversations.starred);
        }
      }
      if (from < 27) {
        if (!await _hasColumn('settings', 'chat_wallpaper')) {
          await m.addColumn(settings, settings.chatWallpaper);
        }
        if (!await _hasColumn('settings', 'chat_wallpaper_dim')) {
          await m.addColumn(settings, settings.chatWallpaperDim);
        }
      }
      if (from < 26) {
        if (!await _hasColumn('settings', 'chat_primary_bubbles')) {
          await m.addColumn(settings, settings.chatPrimaryBubbles);
        }
      }
      if (from < 25) {
        if (!await _hasColumn('chat_conversations', 'avatar_json')) {
          await m.addColumn(chatConversations, chatConversations.avatarJson);
        }
        if (!await _hasColumn('chat_users', 'status')) {
          await m.addColumn(chatUsers, chatUsers.status);
        }
      }
      if (from < 24) {
        // Zalo became the default chat style; installs still on the old
        // default follow it (the style menu changes it any time).
        await customStatement(
          "UPDATE settings SET chat_appearance = 'zalo' "
          "WHERE chat_appearance = 'worknexus'",
        );
      }
      if (from < 23) {
        if (!await _hasColumn('settings', 'chat_cache_limit_mb')) {
          await m.addColumn(settings, settings.chatCacheLimitMb);
        }
      }
      if (from < 22) {
        if (!await _hasColumn('chat_conversations', 'admins_json')) {
          await m.addColumn(chatConversations, chatConversations.adminsJson);
        }
      }
      // Versions 32–35 were used on parallel branches. After a rebase, a DB
      // can report the latest version while still missing another branch's
      // tables or columns. Reconcile them once before any row is read.
      if (from < 36) {
        if (!await _hasTable('zen_tao_profiles')) {
          await m.createTable(zenTaoProfiles);
        }
        for (final (name, column) in [
          ('chat_auto_download_videos', settings.chatAutoDownloadVideos),
          ('chat_auto_download_video_mb', settings.chatAutoDownloadVideoMb),
          ('chat_notify_while_viewing', settings.chatNotifyWhileViewing),
          ('chat_text_scale', settings.chatTextScale),
        ]) {
          if (!await _hasColumn('settings', name)) {
            await m.addColumn(settings, column);
          }
        }
        if (!await _hasColumn('chat_conversations', 'committers')) {
          await m.addColumn(chatConversations, chatConversations.committers);
        }
        // An older branch may have created this column as nullable.
        await customStatement(
          'UPDATE settings SET chat_notify_while_viewing = 0 '
          'WHERE chat_notify_while_viewing IS NULL',
        );
      }
    },
  );

  /// Whether the index [name] exists. Keeps index-creating migrations
  /// idempotent.
  Future<bool> _hasIndex(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Whether the table [name] exists. Lets a migration create a table that
  /// another branch may already have created.
  Future<bool> _hasTable(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Whether [table] already has [column]. Used to keep column-add migrations
  /// idempotent when a dev DB carries a column from a half-applied migration
  /// (added, but the schema version not yet bumped).
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect(
      'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
      variables: [Variable<String>(table), Variable<String>(column)],
    ).get();
    return rows.isNotEmpty;
  }
}
