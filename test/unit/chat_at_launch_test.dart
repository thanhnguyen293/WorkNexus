import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/chat_at_launch.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';

const _first = Account(
  id: 'zt1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);
const _second = Account(
  id: 'zt2',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'other',
);

void main() {
  late StateProvider<String?> chatAccount;
  late ProviderContainer container;

  setUp(() {
    chatAccount = StateProvider<String?>((ref) => null);
    container = ProviderContainer(
      overrides: [
        selectedChatAccountIdProvider.overrideWith(
          (ref) => ref.watch(chatAccount),
        ),
        sortedActiveAccountsProvider.overrideWithValue([_first, _second]),
      ],
    );
    container.listen(launchChatProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  AppNavController nav() => container.read(appNavProvider.notifier);
  RailTarget rail() => container.read(appNavProvider).rail;
  // Riverpod notifies a dependent provider's listeners on the next turn, and
  // the switch itself waits for a microtask after that.
  Future<void> chatArrives() async {
    container.read(chatAccount.notifier).state = 'zt1';
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }

  test('a fresh launch opens the chat once it is known', () async {
    expect(rail(), isA<WorkspaceTarget>());
    await chatArrives();
    expect(rail(), isA<ChatTarget>());
  });

  test('the account the app opened by itself gives way to the chat', () async {
    nav().selectAccount(_first.id);
    await chatArrives();
    expect(rail(), isA<ChatTarget>());
  });

  test('a place the user picked stays', () async {
    nav().selectAccount(_second.id);
    await chatArrives();
    expect(rail(), const RailTarget.account('zt2'));
  });

  test('only at launch: leaving the chat later is not undone', () async {
    await chatArrives();
    nav().selectAccount(_first.id);
    container.read(chatAccount.notifier).state = null;
    await container.pump();
    await chatArrives();
    expect(rail(), const RailTarget.account('zt1'));
  });
}
