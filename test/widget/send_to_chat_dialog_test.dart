import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/send_to_chat_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Repo extends Mock implements ChatRepository {}

const _link = 'https://zt.example/bug-view-12.html';

ChatConversation _group(String gid, String name, {String committers = ''}) =>
    ChatConversation(
      accountId: 'acc',
      gid: gid,
      type: ChatType.group,
      name: name,
      committers: committers,
    );

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(() => repo.watchConversations('acc')).thenAnswer(
      (_) => Stream.value([
        _group('g1', 'Mobile team'),
        _group('g2', 'Backend'),
        _group('g3', 'Announcements', committers: r'$ADMINS'),
      ]),
    );
    when(() => repo.watchUsers('acc')).thenAnswer((_) => Stream.value([]));
    when(() => repo.watchSelfUserId('acc')).thenAnswer((_) => Stream.value(1));
    when(
      () => repo.sendText(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SendToChatDialog.show(
                  context,
                  accountId: 'acc',
                  title: '#12 Crash on login',
                  link: _link,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows what is sent and only chats one may post in', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('#12 Crash on login'), findsOneWidget);
    expect(find.text('Mobile team'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Announcements'), findsNothing, reason: 'admins only');
  });

  testWidgets('sends the message above the link to each picked chat', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('send-to-chat-note')),
      'Please take a look',
    );
    await tester.tap(find.text('Mobile team'));
    await tester.tap(find.text('Backend'));
    await tester.pump();
    await tester.tap(find.text('Send to 2 chats'));
    await tester.pumpAndSettle();

    const text = 'Please take a look\n$_link';
    verify(() => repo.sendText('acc', 'g1', text)).called(1);
    verify(() => repo.sendText('acc', 'g2', text)).called(1);
    expect(find.byType(SendToChatDialog), findsNothing);
    expect(find.text('Sent to 2 chats'), findsOneWidget);
  });

  testWidgets('sends the link alone when no message is typed', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Backend'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    verify(() => repo.sendText('acc', 'g2', _link)).called(1);
    expect(find.text('Sent to chat'), findsOneWidget);
  });
}
