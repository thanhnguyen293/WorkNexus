import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../data/local/repositories/empty_dev_link_repository.dart';
import '../../data/local/repositories/local_activity_repository.dart';
import '../../data/local/repositories/local_comment_repository.dart';
import '../../data/local/repositories/local_ticket_repository.dart';
import '../../data/local/repositories/local_workspace_repository.dart';
import '../../features/agents/data/in_memory_agent_session_repository.dart';
import '../../features/connections/data/local_connection_repository.dart';
import '../../features/connections/domain/repositories/connection_repository.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/translation/data/opencode_translation_service.dart';
import '../../features/translation/data/repositories/local_translation_repository.dart';
import '../../features/translation/domain/adapters/translation_service.dart';
import '../database/database.dart';
import '../domain/repositories/activity_repository.dart';
import '../domain/repositories/agent_session_repository.dart';
import '../domain/repositories/comment_repository.dart';
import '../domain/repositories/dev_link_repository.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/repositories/translation_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../platform/credential_store.dart';
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
  AgentSessionRepository get agentSessionRepository =>
      InMemoryAgentSessionRepository();

  @lazySingleton
  TranslationService get translationService => OpenCodeTranslationService();

  @lazySingleton
  SyncService syncService(AppDatabase db, CredentialStore credentials) =>
      SyncService(db, credentials);
}
