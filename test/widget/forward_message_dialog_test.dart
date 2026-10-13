import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/forward_message_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Repo extends Mock implements ChatRepository {}

final _message = ChatMessage(
  accountId: 'acc',
  gid: 'm1',
  serverId: 9,
  chatGid: 'g1',
  senderId: 2,
  sentAt: DateTime(2026, 10, 13),
  content: const MessageContent.text('xem cái này'),
  isMine: false,
  sendState: SendState.sent,
);

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
        _group('g4', 'Design'),
      ]),
    );
    when(() => repo.watchUsers('acc')).thenAnswer((_) => Stream.value([]));
    when(() => repo.watchSelfUserId('acc')).thenAnswer((_) => Stream.value(1));
    when(
      () => repo.forwardMessage(any(), any(), any()),
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
                onPressed: () => ForwardMessageDialog.show(context, _message),
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

  testWidgets('lists the chats one may post in, filtered by the search', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Mobile team'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Announcements'), findsNothing, reason: 'admins only');

    await tester.enterText(find.byType(TextField), 'back');
    await tester.pump();
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Mobile team'), findsNothing);
  });

  testWidgets('forwards to every picked chat and closes', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Backend'));
    await tester.tap(find.text('Design'));
    await tester.pump();
    await tester.tap(find.text('Forward to 2 chats'));
    await tester.pumpAndSettle();

    verify(() => repo.forwardMessage('acc', 'm1', 'g2')).called(1);
    verify(() => repo.forwardMessage('acc', 'm1', 'g4')).called(1);
    expect(find.byType(ForwardMessageDialog), findsNothing);
    expect(find.text('Forwarded to 2 chats'), findsOneWidget);
  });
}
