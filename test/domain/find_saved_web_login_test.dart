import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/usecases/find_saved_web_login.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';

Account _account({
  String id = 'a',
  ProviderType type = ProviderType.zentao,
  String? baseUrl = 'https://zentao.example.com',
  String? ref = 'secret:a',
}) => Account(
  id: id,
  workspaceId: 'w',
  providerType: type,
  handle: 'Dyno',
  baseUrl: baseUrl,
  credentialsRef: ref,
);

void main() {
  FindSavedWebLogin find(
    List<Account> accounts, {
    Map<String, String>? vault,
  }) => FindSavedWebLogin(
    () => accounts,
    (ref) async => (vault ?? {'secret:a': 'pw'})[ref],
  );

  test('gives the login for a page of the account\'s own server', () async {
    final login = await find([_account()])(
      Uri.parse('https://zentao.example.com/user-login.html'),
    );
    expect(login?.account, 'Dyno');
    expect(login?.password, 'pw');
  });

  test('the default port counts as the scheme\'s own', () async {
    final login = await find([
      _account(baseUrl: 'https://zentao.example.com:443'),
    ])(Uri.parse('https://zentao.example.com/'));
    expect(login, isNotNull);
  });

  test('another host, port or scheme gets nothing', () async {
    final accounts = [_account()];
    for (final url in [
      'https://zentao.example.com.evil.io/',
      'https://evil.zentao.example.com/',
      'https://zentao.example.com:8443/',
      'http://zentao.example.com/',
    ]) {
      expect(await find(accounts)(Uri.parse(url)), isNull, reason: url);
    }
    expect(await find(accounts)(null), isNull);
  });

  test('only a ZenTao account with a saved password counts', () async {
    final page = Uri.parse('https://zentao.example.com/');
    expect(await find([_account(type: ProviderType.gitlab)])(page), isNull);
    expect(await find([_account(ref: null)])(page), isNull);
    expect(await find([_account()], vault: {})(page), isNull);
  });
}
