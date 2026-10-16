import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/platform/app_icon_badge.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_app_badge.dart';

class _MockBadge extends Mock implements AppIconBadge {}

void main() {
  late _MockBadge badge;

  setUpAll(() => registerFallbackValue(const Color(0x00000000)));

  setUp(() {
    badge = _MockBadge();
    when(
      () => badge.show(
        any(),
        color: any(named: 'color'),
        textColor: any(named: 'textColor'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('shows the unread count already there when it appears', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIconBadgeProvider.overrideWithValue(badge),
          chatBadgeUnreadProvider.overrideWithValue(3),
          chatAutoConnectProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const ChatAppBadge(child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    verify(
      () => badge.show(
        3,
        color: any(named: 'color'),
        textColor: any(named: 'textColor'),
      ),
    ).called(1);
  });

  testWidgets('logs into chat as soon as the shell is up', (tester) async {
    var connects = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIconBadgeProvider.overrideWithValue(badge),
          chatBadgeUnreadProvider.overrideWithValue(0),
          chatAutoConnectProvider.overrideWith((ref) => connects++),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const ChatAppBadge(child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(connects, 1);
  });
}
