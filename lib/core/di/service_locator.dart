import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local/repositories/empty_dev_link_repository.dart';
import '../../data/local/repositories/local_activity_repository.dart';
import '../../data/local/repositories/local_comment_repository.dart';
import '../../data/local/repositories/local_ticket_repository.dart';
import '../../data/local/repositories/local_workspace_repository.dart';
import '../../features/agents/data/datasources/opencode_auth_file.dart';
import '../../features/agents/data/datasources/opencode_cli_runner.dart';
import '../../features/agents/data/in_memory_agent_session_repository.dart';
import '../../features/agents/data/repositories/opencode_auth_file_repository.dart';
import '../../features/board/data/repositories/local_saved_filter_repository.dart';
import '../../features/board/domain/repositories/saved_filter_repository.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/xxd/xxd_connection.dart';
import '../../features/chat/data/datasources/xxd/xxd_http_datasource.dart';
import '../../features/chat/data/repositories/http_link_preview_repository.dart';
import '../../features/chat/data/repositories/local_sticker_repository.dart';
import '../../features/chat/data/repositories/local_wallpaper_repository.dart';
import '../../features/chat/data/repositories/xxd_chat_repository.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/repositories/link_preview_repository.dart';
import '../../features/chat/domain/repositories/sticker_repository.dart';
import '../../features/chat/domain/repositories/wallpaper_repository.dart';
import '../../features/connections/data/local_connection_repository.dart';
import '../../features/connections/domain/repositories/connection_repository.dart';
import '../../features/sync/data/merge_request_link_fetcher.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/translation/data/opencode_translation_service.dart';
import '../../features/translation/data/repositories/local_translation_repository.dart';
import '../../features/translation/domain/adapters/translation_service.dart';
import '../database/database.dart';
import '../debug/app_talker.dart';
import '../domain/adapters/github_pr_service.dart';
import '../domain/adapters/gitlab_mr_service.dart';
import '../domain/adapters/merge_request_link_service.dart';
import '../domain/adapters/opencode_cli.dart';
import '../domain/adapters/zentao_ticket_service.dart';
import '../domain/repositories/activity_repository.dart';
import '../domain/repositories/agent_session_repository.dart';
import '../domain/repositories/comment_repository.dart';
import '../domain/repositories/dev_link_repository.dart';
import '../domain/repositories/opencode_auth_repository.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/repositories/translation_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../platform/credential_store.dart';
import '../platform/desktop_notifier.dart';
import 'service_locator.config.dart';

/// The application's service locator (get_it), populated by injectable.
final GetIt getIt = GetIt.instance;

/// Wires the app's object graph for the given [environment]
/// ([Environment.prod] in `main`, [Environment.test] in tests). Everything is a
/// lazy singleton, so nothing is constructed until first used. Call once at
/// startup before the widget tree is built.
@InjectableInit()
Future<void> configureDependencies(String environment) async =>
    getIt.init(environment: environment);

/// The composition root (CLAUDE.md rule 8.1): the single place that binds `data`
/// implementations to their `domain` interfaces. Dependencies flow in through
/// **constructor injection** — each factory method declares what it needs
/// (e.g. [AppDatabase]) and injectable supplies it; no member locates a
/// dependency itself. The database is environment-split so tests get an
/// in-memory instance without touching the production wiring.
@module
abstract class ServiceModule {
  @prod
  @lazySingleton
  AppDatabase get database => AppDatabase();

  @test
  @lazySingleton
  AppDatabase get testDatabase => AppDatabase(NativeDatabase.memory());

  @lazySingleton
  CredentialStore get credentialStore => CredentialStore();

  @lazySingleton
  DesktopNotifier get desktopNotifier => DesktopNotifier();

  @lazySingleton
  ConnectionRepository connectionRepository(AppDatabase db) =>
      LocalConnectionRepository(db);

  @lazySingleton
  TicketRepository ticketRepository(AppDatabase db) =>
      LocalTicketRepository(db);

  @lazySingleton
  WorkspaceRepository workspaceRepository(AppDatabase db) =>
      LocalWorkspaceRepository(db);

  @lazySingleton
  CommentRepository commentRepository(AppDatabase db) =>
      LocalCommentRepository(db);

  @lazySingleton
  ActivityRepository activityRepository(AppDatabase db) =>
      LocalActivityRepository(db);

  @lazySingleton
  DevLinkRepository get devLinkRepository => const EmptyDevLinkRepository();

  @lazySingleton
  TranslationRepository translationRepository(AppDatabase db) =>
      LocalTranslationRepository(db);

  @lazySingleton
  SavedFilterRepository savedFilterRepository(AppDatabase db) =>
      LocalSavedFilterRepository(db);

  @lazySingleton
  ChatRepository chatRepository(AppDatabase db, CredentialStore credentials) =>
      XxdChatRepository(
        local: ChatLocalDatasource(db),
        credentials: credentials,
        openConnection: (c) => XxdConnection(
          credentials: c,
          http: const XxdHttpDatasource(clientVersion: kXxdClientVersion),
        ),
        http: const XxdHttpDatasource(clientVersion: kXxdClientVersion),
        onError: (error, stack) => appTalker.handle(error, stack, 'chat'),
      );

  @lazySingleton
  StickerRepository get stickerRepository => LocalStickerRepository(
    bundle: rootBundle,
    directory: () async =>
        Directory('${(await getApplicationSupportDirectory()).path}/stickers'),
  );

  @lazySingleton
  WallpaperRepository get wallpaperRepository => LocalWallpaperRepository(
    directory: () async => Directory(
      '${(await getApplicationSupportDirectory()).path}/wallpapers',
    ),
  );

  @lazySingleton
  LinkPreviewRepository get linkPreviewRepository =>
      HttpLinkPreviewRepository();

  @lazySingleton
  AgentSessionRepository get agentSessionRepository =>
      InMemoryAgentSessionRepository();

  @lazySingleton
  TranslationService get translationService => OpenCodeTranslationService();

  @lazySingleton
  OpenCodeCli get openCodeCli => const OpenCodeCliRunner();

  @prod
  @lazySingleton
  OpenCodeAuthRepository get openCodeAuthRepository =>
      const OpenCodeAuthFileRepository();

  /// Tests read a throwaway path so they never see — let alone rewrite — the
  /// developer's real OpenCode credentials.
  @test
  @lazySingleton
  OpenCodeAuthRepository get testOpenCodeAuthRepository =>
      OpenCodeAuthFileRepository(
        OpenCodeAuthFile(
          pathOverride:
              '${Directory.systemTemp.path}/work_nexus_test_opencode_auth.json',
        ),
      );

  @lazySingleton
  SyncService syncService(AppDatabase db, CredentialStore credentials) =>
      SyncService(db, credentials);

  @lazySingleton
  GitLabMrService gitLabMrService(SyncService syncService) => syncService;

  @lazySingleton
  GitHubPrService gitHubPrService(SyncService syncService) => syncService;

  @lazySingleton
  ZenTaoTicketService zenTaoTicketService(SyncService syncService) =>
      syncService;

  @lazySingleton
  MergeRequestLinkService mergeRequestLinkService(
    AppDatabase db,
    CredentialStore credentials,
  ) => MergeRequestLinkFetcher(db, credentials);
}
