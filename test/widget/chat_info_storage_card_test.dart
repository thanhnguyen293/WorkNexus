import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_cache_usage.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_info_storage_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _mb = 1024 * 1024;

void main() {
  testWidgets('shows this chat\'s share of the limit, by kind', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatCacheUsageProvider.overrideWith(
            (ref) async => const Ok(
              ChatCacheUsage(
                totalBytes: 300 * _mb,
                limitBytes: 2048 * _mb,
                chats: [
                  ChatCacheChatUsage(
                    accountId: 'acc',
                    chatGid: 'g1',
                    bytes: 120 * _mb,
                    imageBytes: 20 * _mb,
                    videoBytes: 100 * _mb,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: ChatInfoStorageCard(
                thread: (accountId: 'acc', chatGid: 'g1'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('120.0 MB of 2 GB used'), findsOneWidget);
    expect(find.text('20.0 MB'), findsOneWidget);
    expect(find.text('100.0 MB'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);

    // The bar's video segment is about 100/2048 of its width.
    final segments = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .toList();
    final widths = [
      for (final s in segments) tester.getSize(find.byWidget(s)).width,
    ];
    final bar = widths.reduce((a, b) => a > b ? a : b);
    expect(widths.any((w) => w > 0 && w < bar * 0.1), isTrue);
  });
}
