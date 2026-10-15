import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';

class _MemoryCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String ref) async => values[ref];

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;
}

const _account = Account(
  id: 'zt',
  workspaceId: 'ws',
  providerType: ProviderType.zentao,
  handle: 'me',
  baseUrl: 'https://zentao.example',
  credentialsRef: 'zt-secret',
);

void main() {
  late AppDatabase db;
  late SyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sync = SyncService(db, _MemoryCredentialStore());
  });
  tearDown(() => db.close());

  test('one ZenTao client per account while the secret stands', () {
    final first = sync.zenTaoClientFrom(_account, 'pw');
    expect(identical(first, sync.zenTaoClientFrom(_account, 'pw')), isTrue);
  });

  test('a changed secret gets a new client', () {
    final first = sync.zenTaoClientFrom(_account, 'pw');
    final renewed = sync.zenTaoClientFrom(_account, 'new-pw');
    expect(identical(first, renewed), isFalse);
    expect(
      identical(renewed, sync.zenTaoClientFrom(_account, 'new-pw')),
      isTrue,
    );
  });
}
