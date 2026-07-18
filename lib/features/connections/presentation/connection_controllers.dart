import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/workspace.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../core/util/content_hash.dart';
import '../../sync/data/sync_service.dart';
import '../data/provider_adapter_factory.dart';
import '../domain/repositories/connection_repository.dart';

/// State of the add-connection form.
class AddConnectionState {
  const AddConnectionState({this.busy = false, this.error, this.done = false});
  final bool busy;
  final String? error;
  final bool done;
}

class AddConnectionController extends Notifier<AddConnectionState> {
  @override
  AddConnectionState build() => const AddConnectionState();

  void reset() => state = const AddConnectionState();

  /// Tests the ZenTao connection, stores the password in the keychain, persists
  /// the account, and runs an initial sync. Returns true if the account was added.
  ///
  /// Provide EITHER [workspaceId] (existing) OR [newWorkspaceName] (created here).
  Future<bool> connectZenTao({
    required String baseUrl,
    required String username,
    required String password,
    String? workspaceId,
    String? newWorkspaceName,
  }) async {
    state = const AddConnectionState(busy: true);
    if (baseUrl.trim().isEmpty || username.trim().isEmpty || password.isEmpty) {
      state = const AddConnectionState(error: 'All fields are required');
      return false;
    }

    // Resolve the target workspace, creating a new one if requested.
    String targetWorkspaceId;
    final newName = newWorkspaceName?.trim() ?? '';
    if (newName.isNotEmpty) {
      final wsId = 'ws-${_slug(newName)}-${intHash(newName).toRadixString(16)}';
      await getIt<ConnectionRepository>().addWorkspace(
        Workspace(
          id: wsId,
          name: newName,
          shortCode: _initials(newName),
          colorValue: _pickColor(newName),
        ),
      );
      targetWorkspaceId = wsId;
    } else if (workspaceId != null && workspaceId.isNotEmpty) {
      targetWorkspaceId = workspaceId;
    } else {
      state = const AddConnectionState(error: 'Choose or create a workspace');
      return false;
    }

    final accountId =
        'zt-${_slug(username)}-${intHash(baseUrl).toRadixString(16)}';
    final credRef = CredentialStore.refFor(accountId);
    final account = Account(
      id: accountId,
      workspaceId: targetWorkspaceId,
      providerType: ProviderType.zentao,
      handle: username.trim(),
      baseUrl: baseUrl.trim(),
      credentialsRef: credRef,
    );

    final adapter = buildProviderAdapter(account, password)!;
    final check = await adapter.testConnection();
    switch (check) {
      case Err(:final failure):
        state = AddConnectionState(error: failure.message);
        return false;
      case Ok(:final value):
        if (!value.ok) {
          state = AddConnectionState(error: value.error ?? 'Connection failed');
          return false;
        }
    }

    await getIt<CredentialStore>().write(credRef, password);
    await getIt<ConnectionRepository>().addAccount(account);
    final sync = await getIt<SyncService>().syncAccount(account);
    switch (sync) {
      case Err(:final failure):
        // Account is connected but the first sync failed — keep it, surface the error.
        state = AddConnectionState(
          error: 'Connected, but sync failed: ${failure.message}',
        );
        return true;
      case Ok():
        state = const AddConnectionState(done: true);
        return true;
    }
  }

  String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Up-to-2-letter badge from a workspace name ("Company C" → "CC", "Erp" → "E").
  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static const _palette = [
    0xFF16A99C,
    0xFFCF8A3A,
    0xFF8F63D6,
    0xFF3B82F6,
    0xFFE05561,
    0xFF2F8A52,
  ];

  int _pickColor(String name) => _palette[intHash(name) % _palette.length];
}

final addConnectionControllerProvider =
    NotifierProvider<AddConnectionController, AddConnectionState>(
      AddConnectionController.new,
    );
