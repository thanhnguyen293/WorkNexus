import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/data/repositories/empty_dev_link_repository.dart';
import '../../core/data/repositories/local_activity_repository.dart';
import '../../core/data/repositories/local_comment_repository.dart';
import '../../core/data/repositories/local_ticket_repository.dart';
import '../../core/data/repositories/local_workspace_repository.dart';
import '../../core/data/repositories/settings_sync_status_repository.dart';
import '../../core/database/database.dart';
import '../../core/debug/app_talker.dart';
import '../../core/di/locator.dart';
import '../../core/domain/adapters/account_sync_service.dart';
import '../../core/domain/adapters/github_pr_service.dart';
import '../../core/domain/adapters/gitlab_mr_service.dart';
import '../../core/domain/adapters/merge_request_link_service.dart';
import '../../core/domain/adapters/opencode_cli.dart';
import '../../core/domain/adapters/provider_adapter_registry.dart';
import '../../core/domain/adapters/ticket_detail_service.dart';
import '../../core/domain/adapters/zentao_ticket_editor.dart';
import '../../core/domain/adapters/zentao_ticket_service.dart';
import '../../core/domain/adapters/zentao_workflow_service.dart';
import '../../core/domain/repositories/activity_repository.dart';
import '../../core/domain/repositories/comment_repository.dart';
import '../../core/domain/repositories/dev_link_repository.dart';
import '../../core/domain/repositories/sync_status_repository.dart';
import '../../core/domain/repositories/ticket_repository.dart';
import '../../core/domain/repositories/workspace_repository.dart';
import '../../core/platform/app_icon_badge.dart';
import '../../core/platform/app_image.dart';
import '../../core/platform/credential_store.dart';
import '../../core/platform/desktop_notifier.dart';
import '../../features/app_update/data/datasources/appimage_update_installer.dart';
import '../../features/app_update/data/datasources/github_release_datasource.dart';
import '../../features/app_update/data/datasources/linux_update_installer.dart';
import '../../features/app_update/data/datasources/macos_update_installer.dart';
import '../../features/app_update/data/datasources/windows_update_installer.dart';
import '../../features/app_update/data/repositories/github_update_repository.dart';
import '../../features/app_update/domain/repositories/update_repository.dart';
import '../../features/app_update/domain/usecases/check_for_update.dart';
import '../../features/app_update/domain/usecases/download_update.dart';
import '../../features/app_update/domain/usecases/install_update.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/link_preview_http_datasource.dart';
import '../../features/chat/data/datasources/link_preview_local_datasource.dart';
import '../../features/chat/data/datasources/telegram_sticker_source.dart';
import '../../features/chat/data/datasources/webp_sticker_converter.dart';
import '../../features/chat/data/datasources/xxd/xxd_connection.dart';
import '../../features/chat/data/datasources/xxd/xxd_http_datasource.dart';
import '../../features/chat/data/repositories/cached_link_preview_repository.dart';
import '../../features/chat/data/repositories/keychain_telegram_token_store.dart';
import '../../features/chat/data/repositories/local_message_translation_repository.dart';
import '../../features/chat/data/repositories/local_sticker_repository.dart';
import '../../features/chat/data/repositories/local_wallpaper_repository.dart';
import '../../features/chat/data/repositories/xxd_chat_repository.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/repositories/link_preview_repository.dart';
import '../../features/chat/domain/repositories/message_translation_repository.dart';
import '../../features/chat/domain/repositories/sticker_pack_source.dart';
import '../../features/chat/domain/repositories/sticker_repository.dart';
import '../../features/chat/domain/repositories/wallpaper_repository.dart';
import '../../features/chat/domain/usecases/translate_chat_message.dart';
import '../../features/connections/data/local_connection_repository.dart';
import '../../features/connections/data/repositories/drift_local_cache_repository.dart';
import '../../features/connections/domain/repositories/connection_repository.dart';
import '../../features/connections/domain/repositories/local_cache_repository.dart';
import '../../features/connections/domain/usecases/clear_local_cache.dart';
import '../../features/mini_apps/data/datasources/favicon_fetcher.dart';
import '../../features/mini_apps/data/datasources/mini_app_icon_storage.dart';
import '../../features/mini_apps/data/datasources/mini_app_local_datasource.dart';
import '../../features/mini_apps/data/datasources/mini_app_permission_local_datasource.dart';
import '../../features/mini_apps/data/datasources/web_profile_datasource.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_browsing_data_repository.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_permission_repository.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_browsing_data_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_permission_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_repository.dart';
import '../../features/mini_apps/domain/usecases/add_mini_app.dart';
import '../../features/mini_apps/domain/usecases/move_mini_app.dart';
import '../../features/mini_apps/domain/usecases/refresh_mini_app_icon.dart';
import '../../features/mini_apps/domain/usecases/resolve_mini_app_permission.dart';
import '../../features/mini_apps/domain/usecases/update_mini_app.dart';
import '../../features/notifications/data/datasources/notification_local_datasource.dart';
import '../../features/notifications/data/repositories/zentao_notification_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/refresh_notifications.dart';
import '../../features/ticket_editor/data/datasources/ticket_draft_local_datasource.dart';
import '../../features/ticket_editor/data/repositories/local_ticket_draft_repository.dart';
import '../../features/ticket_editor/domain/repositories/ticket_draft_repository.dart';
import '../../features/translation/data/api_translation_service.dart';
import '../../features/translation/data/datasources/cli_runner.dart';
import '../../features/translation/data/datasources/openai_model_catalog_datasource.dart';
import '../../features/translation/data/datasources/opencode_auth_file.dart';
import '../../features/translation/data/datasources/opencode_cli_runner.dart';
import '../../features/translation/data/opencode_translation_service.dart';
import '../../features/translation/data/repositories/credential_translation_api_config_repository.dart';
import '../../features/translation/data/repositories/local_translation_repository.dart';
import '../../features/translation/data/repositories/opencode_auth_file_key_repository.dart';
import '../../features/translation/data/routing_translation_service.dart';
import '../../features/translation/domain/adapters/translation_service.dart';
import '../../features/translation/domain/entities/translation_api_config.dart';
import '../../features/translation/domain/repositories/opencode_key_repository.dart';
import '../../features/translation/domain/repositories/translation_api_config_repository.dart';
import '../../features/translation/domain/repositories/translation_api_model_catalog.dart';
import '../../features/translation/domain/repositories/translation_repository.dart';
import '../../features/workspace_overview/data/datasources/dashboard_local_datasource.dart';
import '../../features/workspace_overview/data/repositories/zentao_dashboard_repository.dart';
import '../../features/workspace_overview/domain/repositories/dashboard_repository.dart';
import '../../features/workspace_overview/domain/usecases/refresh_dashboard.dart';
import '../../shared/board/data/repositories/local_saved_filter_repository.dart';
import '../../shared/board/domain/repositories/saved_filter_repository.dart';
import '../../shared/sync/data/merge_request_link_fetcher.dart';
import '../../shared/sync/data/sync_coordinator.dart';
import '../../tools/github/data/services/github_pr_service_impl.dart';
import '../../tools/gitlab/data/services/gitlab_mr_service_impl.dart';
import '../../tools/zentao/data/datasources/zentao_client.dart';
import '../../tools/zentao/data/repositories/local_zentao_profile_repository.dart';
import '../../tools/zentao/data/services/zentao_ticket_editor_service.dart';
import '../../tools/zentao/data/services/zentao_ticket_service_impl.dart';
import '../../tools/zentao/data/services/zentao_workflow_actions.dart';
import '../../tools/zentao/domain/repositories/zentao_profile_repository.dart';
import '../../tools/zentao/domain/repositories/zentao_task_bugs.dart';
import '../../tools/zentao/domain/repositories/zentao_view_pages.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_profile.dart';
import '../../tools/zentao/domain/usecases/update_zentao_profile.dart';
import 'provider_adapter_registry_impl.dart';
import 'service_locator.config.dart';

export '../../core/di/locator.dart';

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
    // Only a release build replaces itself: a debug / profile build runs from
    // build/, which an update would overwrite with the release. Without an
    // installer an update is still reported, as a manual download.
    installer: !kReleaseMode
        ? null
        : Platform.isWindows
        ? const WindowsUpdateInstaller()
        : Platform.isMacOS
        ? const MacosUpdateInstaller()
        : Platform.isLinux
        ? switch (runningAppImage()) {
            final appImage? => AppImageUpdateInstaller(appImage),
            null => const LinuxUpdateInstaller(),
          }
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
  AppIconBadge get appIconBadge => AppIconBadge();

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
    SyncCoordinator coordinator,
  ) => LocalZenTaoProfileRepository(
    db,
    credentials,
    // The sync's pooled client, so the profile refresh shares its session.
    clientFactory: (account, password) =>
        switch (coordinator.buildAdapter(account, password)?.rawClient) {
          final ZenTaoClient pooled => pooled,
          _ => ZenTaoClient(
            baseUrl: account.baseUrl ?? '',
            account: account.handle,
            password: password,
          ),
        },
  );

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
  StickerRepository stickerRepository(StickerConverter converter) =>
      LocalStickerRepository(
        bundle: rootBundle,
        directory: () async => Directory(
          '${(await getApplicationSupportDirectory()).path}/stickers',
        ),
        converter: converter,
      );

  @lazySingleton
  StickerPackSource get stickerPackSource => TelegramStickerSource();

  @lazySingleton
  StickerConverter get stickerConverter => const WebpStickerConverter();

  @lazySingleton
  TelegramTokenStore telegramTokenStore(CredentialStore credentials) =>
      KeychainTelegramTokenStore(credentials);

  @lazySingleton
  WallpaperRepository get wallpaperRepository => LocalWallpaperRepository(
    directory: () async => Directory(
      '${(await getApplicationSupportDirectory()).path}/wallpapers',
    ),
  );

  @lazySingleton
  LinkPreviewRepository linkPreviewRepository(AppDatabase db) =>
      CachedLinkPreviewRepository(
        local: LinkPreviewLocalDatasource(db),
        http: LinkPreviewHttpDatasource(),
      );

  @lazySingleton
  TranslationApiConfigRepository translationApiConfigRepository(
    CredentialStore credentials,
  ) => CredentialTranslationApiConfigRepository(credentials);

  @lazySingleton
  TranslationApiModelCatalog get translationApiModelCatalog =>
      OpenAiModelCatalogDatasource(Dio());

  /// One resolver for every OpenCode caller, so the binary is looked up once.
  @lazySingleton
  CliRunner get cliRunner => CliRunner();

  @lazySingleton
  TranslationService translationService(
    TranslationApiConfigRepository configs,
    CliRunner runner,
  ) {
    Future<TranslationApiConfig?> config() async =>
        (await configs.load()).valueOrNull;
    return RoutingTranslationService(
      api: ApiTranslationService(Dio(), config),
      openCode: OpenCodeTranslationService(runner: runner),
      config: config,
    );
  }

  @lazySingleton
  OpenCodeCli openCodeCli(CliRunner runner) => OpenCodeCliRunner(runner);

  @prod
  @lazySingleton
  OpenCodeKeyRepository get openCodeKeyRepository =>
      const OpenCodeAuthFileKeyRepository();

  /// Tests read a throwaway path so they never see — let alone rewrite — the
  /// developer's real OpenCode credentials.
  @test
  @lazySingleton
  OpenCodeKeyRepository get testOpenCodeKeyRepository =>
      OpenCodeAuthFileKeyRepository(
        OpenCodeAuthFile(
          pathOverride:
              '${Directory.systemTemp.path}/work_nexus_test_opencode_auth.json',
        ),
      );

  @lazySingleton
  SyncCoordinator syncCoordinator(
    AppDatabase db,
    CredentialStore credentials,
    ProviderAdapterRegistry registry,
    SyncStatusRepository syncStatusRepository,
  ) => SyncCoordinator(
    db,
    credentials,
    registry: registry,
    statusRepository: syncStatusRepository,
  );

  @lazySingleton
  TicketDetailService ticketDetailService(SyncCoordinator coordinator) =>
      coordinator;

  @lazySingleton
  AccountSyncService accountSyncService(SyncCoordinator coordinator) =>
      coordinator;

  @lazySingleton
  GitLabMrService gitLabMrService(SyncCoordinator coordinator) =>
      GitLabMrServiceImpl(coordinator);

  @lazySingleton
  GitHubPrService gitHubPrService(SyncCoordinator coordinator) =>
      GitHubPrServiceImpl(coordinator);

  @lazySingleton
  ZenTaoTicketServiceImpl zenTaoTicketServiceImpl(
    SyncCoordinator coordinator,
  ) => ZenTaoTicketServiceImpl(coordinator: coordinator);

  @lazySingleton
  ZenTaoTicketService zenTaoTicketService(ZenTaoTicketServiceImpl impl) => impl;

  @lazySingleton
  ZenTaoViewPages zenTaoViewPages(ZenTaoTicketServiceImpl impl) => impl;

  @lazySingleton
  ZenTaoTaskBugs zenTaoTaskBugs(ZenTaoTicketServiceImpl impl) => impl;

  @lazySingleton
  ZenTaoWorkflowService zenTaoWorkflowService(SyncCoordinator coordinator) =>
      ZenTaoWorkflowActions(coordinator);

  @lazySingleton
  ZenTaoTicketEditor zenTaoTicketEditor(
    SyncCoordinator coordinator,
    ZenTaoTicketService ticketService,
  ) => ZenTaoTicketEditorService(
    coordinator: coordinator,
    ticketService: ticketService,
  );

  @lazySingleton
  DashboardRepository dashboardRepository(
    AppDatabase db,
    ZenTaoTicketService zenTaoTicketService,
    AccountSyncService accountSyncService,
  ) => ZenTaoDashboardRepository(
    local: DashboardLocalDatasource(db),
    fetch: zenTaoTicketService.fetchZenTaoUserInfo,
    syncAssigned: accountSyncService.syncAccountById,
  );

  @lazySingleton
  NotificationRepository notificationRepository(
    AppDatabase db,
    ZenTaoTicketService zenTaoTicketService,
  ) => ZenTaoNotificationRepository(
    local: NotificationLocalDatasource(db),
    fetch: zenTaoTicketService.fetchZenTaoMessages,
    run: zenTaoTicketService.zenTaoMessageAction,
  );

  @lazySingleton
  RefreshNotifications refreshNotifications(
    NotificationRepository repository,
  ) => RefreshNotifications(repository);

  @lazySingleton
  MiniAppRepository miniAppRepository(AppDatabase db) => LocalMiniAppRepository(
    MiniAppLocalDatasource(db),
    MiniAppIconStorage(
      () async => Directory(
        '${(await getApplicationSupportDirectory()).path}/mini_app_icons',
      ),
    ),
    FaviconFetcher(),
  );

  @lazySingleton
  RefreshMiniAppIcon refreshMiniAppIcon(MiniAppRepository repository) =>
      RefreshMiniAppIcon(repository);

  @lazySingleton
  AddMiniApp addMiniApp(
    MiniAppRepository repository,
    RefreshMiniAppIcon refreshIcon,
  ) => AddMiniApp(repository, refreshIcon);

  @lazySingleton
  MiniAppPermissionRepository miniAppPermissionRepository(AppDatabase db) =>
      LocalMiniAppPermissionRepository(MiniAppPermissionLocalDatasource(db));

  @lazySingleton
  ResolveMiniAppPermission resolveMiniAppPermission(
    MiniAppPermissionRepository repository,
  ) => ResolveMiniAppPermission(repository);

  @lazySingleton
  UpdateMiniApp updateMiniApp(
    MiniAppRepository repository,
    RefreshMiniAppIcon refreshIcon,
  ) => UpdateMiniApp(repository, refreshIcon);

  @lazySingleton
  MoveMiniApp moveMiniApp(MiniAppRepository repository) =>
      MoveMiniApp(repository);

  @lazySingleton
  MiniAppBrowsingDataRepository miniAppBrowsingDataRepository() =>
      const LocalMiniAppBrowsingDataRepository(WebProfileDatasource());

  @lazySingleton
  TicketDraftRepository ticketDraftRepository(AppDatabase db) =>
      LocalTicketDraftRepository(TicketDraftLocalDatasource(db));

  @lazySingleton
  RefreshDashboard refreshDashboard(DashboardRepository repository) =>
      RefreshDashboard(repository);

  @lazySingleton
  MergeRequestLinkService mergeRequestLinkService(
    AppDatabase db,
    CredentialStore credentials,
    ProviderAdapterRegistry registry,
  ) => MergeRequestLinkFetcher(db, credentials, registry);

  @lazySingleton
  SyncStatusRepository syncStatusRepository(AppDatabase db) =>
      SettingsSyncStatusRepository(db);

  @lazySingleton
  ProviderAdapterRegistry get providerAdapterRegistry =>
      const ProviderAdapterRegistryImpl();
}
