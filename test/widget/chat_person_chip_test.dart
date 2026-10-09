import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_person_chip.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatUsersProvider('acc').overrideWith(
            (ref) => Stream.value({
              7: const ChatUser(
                accountId: 'acc',
                userId: 7,
                account: 'ryan',
                realname: 'Ryan_VN_test',
                role: 'pm',
              ),
            }),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: ChatPersonChip(accountId: 'acc', name: name, avatarSize: 28),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a known person shows as chat knows them, tappable', (
    tester,
  ) async {
    // Tickets name the assignee by login handle.
    await pump(tester, 'Ryan');

    expect(find.text('Ryan_VN_test'), findsOneWidget);
    expect(find.byTooltip('Chat with Ryan_VN_test'), findsOneWidget);
    final avatar = tester.widget<ChatAvatar>(find.byType(ChatAvatar));
    expect(avatar.verified, isNotNull, reason: 'a PM gets the check');
    expect(avatar.diameter, 28);
  });

  testWidgets('someone chat does not know is shown but not tappable', (
    tester,
  ) async {
    await pump(tester, 'Stranger');

    expect(find.text('Stranger'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(tester.widget<ChatAvatar>(find.byType(ChatAvatar)).verified, isNull);
  });
}
