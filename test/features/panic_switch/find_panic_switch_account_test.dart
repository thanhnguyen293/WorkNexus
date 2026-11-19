import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/find_panic_switch_account.dart';

void main() {
  const useCase = FindPanicSwitchAccount();

  Account account(String id, ProviderType type, String? url) => Account(
    id: id,
    workspaceId: 'w',
    providerType: type,
    handle: 'h',
    baseUrl: url,
  );

  test('finds the ZenTao account on the supported server', () {
    final match = account(
      'z2',
      ProviderType.zentao,
      'HTTPS://zentao.oasoft.xyz:4433/zentao/',
    );
    expect(
      useCase([
        account('z1', ProviderType.zentao, 'https://other.example/zentao'),
        account(
          'g',
          ProviderType.github,
          'https://zentao.oasoft.xyz:4433/zentao',
        ),
        match,
      ]),
      match,
    );
  });

  test('is null when no account matches', () {
    expect(
      useCase([account('z1', ProviderType.zentao, 'https://other.example')]),
      isNull,
    );
  });
}
