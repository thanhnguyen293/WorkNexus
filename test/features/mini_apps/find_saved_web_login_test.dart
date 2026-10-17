import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/find_saved_web_login.dart';

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

  Future<SavedWebLogin?> login(
    List<Account> accounts,
    String? url, {
    Map<String, String>? vault,
  }) async => (await find(accounts, vault: vault)(
    url == null ? null : Uri.parse(url),
  )).valueOrNull;

  test('gives the login on the login page of the account\'s server', () async {
    final found = await login([
      _account(),
    ], 'https://zentao.example.com/user-login.html');
    expect(found?.account, 'Dyno');
    expect(found?.password, 'pw');
  });

  test('knows the login page in each URL style', () async {
    for (final url in [
      'https://zentao.example.com/zentao/user-login-L3plbnRhby8=.html',
      'https://zentao.example.com/index.php?m=user&f=login',
    ]) {
      expect(await login([_account()], url), isNotNull, reason: url);
    }
  });

  test('another page of the same server gets nothing', () async {
    for (final url in [
      'https://zentao.example.com/',
      'https://zentao.example.com/user-edit-1.html',
      'https://zentao.example.com/my-changepassword.html',
      'https://zentao.example.com/index.php?m=user&f=delete',
    ]) {
      expect(await login([_account()], url), isNull, reason: url);
    }
  });

  test('the default port counts as the scheme\'s own', () async {
    final found = await login([
      _account(baseUrl: 'https://zentao.example.com:443'),
    ], 'https://zentao.example.com/user-login.html');
    expect(found, isNotNull);
  });

  test('another host, port or scheme gets nothing', () async {
    final accounts = [_account()];
    for (final url in [
      'https://zentao.example.com.evil.io/user-login.html',
      'https://evil.zentao.example.com/user-login.html',
      'https://zentao.example.com:8443/user-login.html',
      'http://zentao.example.com/user-login.html',
    ]) {
      expect(await login(accounts, url), isNull, reason: url);
    }
    expect(await login(accounts, null), isNull);
  });

  test('only a ZenTao account with a saved password counts', () async {
    const page = 'https://zentao.example.com/user-login.html';
    expect(await login([_account(type: ProviderType.gitlab)], page), isNull);
    expect(await login([_account(ref: null)], page), isNull);
    expect(await login([_account()], page, vault: {}), isNull);
  });

  test('a password store that fails gives a failure, not a throw', () async {
    final result = await FindSavedWebLogin(
      () => [_account()],
      (_) async => throw Exception('keychain locked'),
    )(Uri.parse('https://zentao.example.com/user-login.html'));
    expect(result.failureOrNull, isA<StorageFailure>());
  });
}
