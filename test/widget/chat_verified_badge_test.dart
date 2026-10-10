import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_labels.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Map<int, ChatUser> withRole(String role) => {
    1: ChatUser(
      accountId: 'acc',
      userId: 1,
      account: 'lead',
      realname: 'Lead',
      role: role,
    ),
  };

  Future<void> pumpAvatar(WidgetTester tester, String role) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ChatAvatar(
                  name: 'Lead',
                  verified: chatVerifiedBadge(context, withRole(role), 1),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('hovering the check shows the legend of every check', (
    tester,
  ) async {
    await pumpAvatar(tester, 'td');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byIcon(Icons.verified_rounded)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Role badges'), findsOneWidget);
    // Only the viewed user's role is highlighted (its own label).
    expect(find.text('Technical Manager'), findsOneWidget);
    expect(
      find.textContaining('Product Manager, Test Manager', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('No check: Developẻ, Test Engineer', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('engineers get no check', (tester) async {
    await pumpAvatar(tester, 'dev');
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });
}
