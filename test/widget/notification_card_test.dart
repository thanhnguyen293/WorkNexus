import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/notifications/domain/entities/zentao_notification.dart';
import 'package:work_nexus/features/notifications/presentation/widgets/notification_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

final _notification = ZenTaoNotification(
  accountId: 'zt',
  id: '1',
  summary: 'JunNg-VN-Flutter assigned Bug',
  objectType: 'bug',
  objectId: '6492',
  objectTitle:
      '[Discover] Feed: Video autoplay is delayed after fast scrolling',
  createdAt: DateTime(2026, 10, 9, 11, 22),
);

Future<void> pumpCard(
  WidgetTester tester,
  ZenTaoNotification n, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 380, child: NotificationCard(notification: n)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('who did what leads; the ticket follows, the time sits right', (
    tester,
  ) async {
    await pumpCard(tester, _notification);

    final event = tester.getRect(find.text('JunNg-VN-Flutter assigned Bug'));
    final ticket = tester.getRect(find.textContaining('[Discover] Feed'));
    final time = tester.getRect(find.text('11:22'));
    expect(event.top, lessThan(ticket.top));
    expect(find.textContaining('#6492'), findsOneWidget);
    // The time shares the event's line, at the card's right.
    expect(time.left, greaterThan(event.left));
    expect(time.top, lessThan(ticket.top));
  });

  testWidgets('hovering swaps the time for the read / delete actions', (
    tester,
  ) async {
    await pumpCard(tester, _notification);
    expect(find.byTooltip('Mark as read'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(NotificationCard)));
    await tester.pump();

    expect(find.text('11:22'), findsNothing);
    expect(find.byTooltip('Mark as read'), findsOneWidget);
  });

  testWidgets("ZenTao's Chinese text shows in the app's language", (
    tester,
  ) async {
    final chinese = _notification.copyWith(summary: 'Thanh-VN-Flutter指派了Bug');

    await pumpCard(tester, chinese);
    expect(find.text('Thanh-VN-Flutter assigned Bug'), findsOneWidget);

    await pumpCard(tester, chinese, locale: const Locale('vi'));
    await tester.pumpAndSettle();
    expect(find.text('Thanh-VN-Flutter đã giao Bug'), findsOneWidget);
  });

  testWidgets('an event it cannot read is shown as ZenTao wrote it', (
    tester,
  ) async {
    await pumpCard(tester, _notification.copyWith(summary: 'JunNg 提到了你'));

    expect(find.text('JunNg 提到了你'), findsOneWidget);
  });
}
