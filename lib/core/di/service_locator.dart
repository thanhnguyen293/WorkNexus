import 'dart:io';

import 'package:dio/dio.dart';
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
import '../../features/app_update/data/datasources/github_release_datasource.dart';
import '../../features/app_update/data/datasources/macos_update_installer.dart';
import '../../features/app_update/data/datasources/windows_update_installer.dart';
import '../../features/app_update/data/repositories/github_update_repository.dart';
import '../../features/app_update/domain/repositories/update_repository.dart';
import '../../features/app_update/domain/usecases/check_for_update.dart';
import '../../features/app_update/domain/usecases/download_update.dart';
import '../../features/app_update/domain/usecases/install_update.dart';
import '../../features/board/data/repositories/local_saved_filter_repository.dart';
import '../../features/board/domain/repositories/saved_filter_repository.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/xxd/xxd_connection.dart';
import '../../features/chat/data/datasources/xxd/xxd_http_datasource.dart';
import '../../features/chat/data/repositories/http_link_preview_repository.dart';
import '../../features/chat/data/repositories/local_message_translation_repository.dart';
import '../../features/chat/data/repositories/local_sticker_repository.dart';
import '../../features/chat/data/repositories/local_wallpaper_repository.dart';
import '../../features/chat/data/repositories/xxd_chat_repository.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/repositories/link_preview_repository.dart';
import '../../features/chat/domain/repositories/message_translation_repository.dart';
import '../../features/chat/domain/repositories/sticker_repository.dart';
import '../../features/chat/domain/repositories/wallpaper_repository.dart';
import '../../features/chat/domain/usecases/translate_chat_message.dart';
import '../../features/connections/data/local_connection_repository.dart';
import '../../features/connections/data/repositories/drift_local_cache_repository.dart';
import '../../features/connections/data/repositories/local_zentao_profile_repository.dart';
import '../../features/connections/domain/repositories/connection_repository.dart';
import '../../features/connections/domain/repositories/local_cache_repository.dart';
import '../../features/connections/domain/repositories/zentao_profile_repository.dart';
import '../../features/connections/domain/usecases/clear_local_cache.dart';
import '../../features/connections/domain/usecases/refresh_zentao_profile.dart';
import '../../features/connections/domain/usecases/update_zentao_profile.dart';
import '../../features/dashboard/data/datasources/dashboard_local_datasource.dart';
import '../../features/dashboard/data/repositories/zentao_dashboard_repository.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/refresh_dashboard.dart';
import '../../features/notifications/data/datasources/notification_local_datasource.dart';
import '../../features/notifications/data/repositories/zentao_notification_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/refresh_notifications.dart';
import '../../features/sync/data/merge_request_link_fetcher.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/sync/data/zentao_ticket_editor_service.dart';
import '../../features/sync/data/zentao_workflow_actions.dart';
import '../../features/translation/data/api_translation_service.dart';
import '../../features/translation/data/opencode_translation_service.dart';
import '../../features/translation/data/repositories/credential_translation_api_config_repository.dart';
import '../../features/translation/data/repositories/local_translation_repository.dart';
import '../../features/translation/data/routing_translation_service.dart';
import '../../features/translation/domain/adapters/translation_service.dart';
import '../../features/translation/domain/entities/translation_api_config.dart';
import '../../features/translation/domain/repositories/translation_api_config_repository.dart';
import '../config/app_config.dart';
import '../database/database.dart';
import '../debug/app_talker.dart';
import '../domain/adapters/github_pr_service.dart';
import '../domain/adapters/gitlab_mr_service.dart';
import '../domain/adapters/merge_request_link_service.dart';
import '../domain/adapters/opencode_cli.dart';
import '../domain/adapters/zentao_ticket_editor.dart';
import '../domain/adapters/zentao_ticket_service.dart';
import '../domain/adapters/zentao_workflow_service.dart';
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
  @lazySingleton
  GitHubReleaseDatasource get githubReleaseDatasource =>
      GitHubReleaseDatasource(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      );

  @lazySingleton
  UpdateRepository updateRepository(
    GitHubReleaseDatasource releaseDatasource,
  ) => GitHubUpdateRepository(
    releases: releaseDatasource,
    installer: Platform.isWindows
        ? const WindowsUpdateInstaller()
        : Platform.isMacOS
        ? const MacosUpdateInstaller()
        : null,
    stagingRoot: () async => Directory(
      '${(await getTemporaryDirectory()).path}/${AppConfig.databaseName}-update',
    ),
  );

  @lazySingleton
  CheckForUpdate checkForUpdate(UpdateRepository repository) =>
      CheckForUpdate(repository);

  @lazySingleton
  DownloadUpdate downloadUpdate(UpdateRepository repository) =>
      DownloadUpdate(repository);

  @lazySingleton
  InstallUpdate installUpdate(UpdateRepository repository) =>
      InstallUpdate(repository);

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
  LocalCacheRepository localCacheRepository(AppDatabase db) =>
      DriftLocalCacheRepository(db);

  @lazySingleton
  ClearLocalCache clearLocalCache(LocalCacheRepository repository) =>
      ClearLocalCache(repository);

  @lazySingleton
  ZenTaoProfileRepository zenTaoProfileRepository(
    AppDatabase db,
    CredentialStore credentials,
  ) => LocalZenTaoProfileRepository(db, credentials);

  @lazySingleton
  RefreshZenTaoProfile refreshZenTaoProfile(
    ZenTaoProfileRepository repository,
  ) => RefreshZenTaoProfile(repository);

  @lazySingleton
  UpdateZenTaoProfile updateZenTaoProfile(ZenTaoProfileRepository repository) =>
      UpdateZenTaoProfile(repository);

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
  MessageTranslationRepository messageTranslationRepository(AppDatabase db) =>
      LocalMessageTranslationRepository(ChatLocalDatasource(db));

  @lazySingleton
  TranslateChatMessage translateChatMessage(
    MessageTranslationRepository repository,
    TranslationService service,
  ) => TranslateChatMessage(repository, service);

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
  TranslationApiConfigRepository translationApiConfigRepository(
    CredentialStore credentials,
  ) => CredentialTranslationApiConfigRepository(credentials);

  @lazySingleton
  TranslationService translationService(
    TranslationApiConfigRepository configs,
  ) {
    Future<TranslationApiConfig?> config() async =>
        (await configs.load()).valueOrNull;
    return RoutingTranslationService(
      api: ApiTranslationService(Dio(), config),
      openCode: OpenCodeTranslationService(),
      config: config,
    );
  }

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
  ZenTaoTicketEditor zenTaoTicketEditor(SyncService syncService) =>
      ZenTaoTicketEditorService(syncService);

  @lazySingleton
  ZenTaoWorkflowService zenTaoWorkflowService(SyncService syncService) =>
      ZenTaoWorkflowActions(syncService);

  @lazySingleton
  DashboardRepository dashboardRepository(
    AppDatabase db,
    SyncService syncService,
  ) => ZenTaoDashboardRepository(
    local: DashboardLocalDatasource(db),
    fetch: syncService.fetchZenTaoUserInfo,
    syncAssigned: syncService.syncAccountById,
  );

  @lazySingleton
  NotificationRepository notificationRepository(
    AppDatabase db,
    SyncService syncService,
  ) => ZenTaoNotificationRepository(
    local: NotificationLocalDatasource(db),
    fetch: syncService.fetchZenTaoMessages,
    run: syncService.zenTaoMessageAction,
  );

  @lazySingleton
  RefreshNotifications refreshNotifications(
    NotificationRepository repository,
  ) => RefreshNotifications(repository);

  @lazySingleton
  RefreshDashboard refreshDashboard(DashboardRepository repository) =>
      RefreshDashboard(repository);

  @lazySingleton
  MergeRequestLinkService mergeRequestLinkService(
    AppDatabase db,
    CredentialStore credentials,
  ) => MergeRequestLinkFetcher(db, credentials);
}
