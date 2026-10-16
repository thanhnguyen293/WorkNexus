import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_product_tree_node.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';

const _account = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'me',
);
const _product = ProviderProduct(id: '12', name: 'Wallet', accountId: 'zt');

void main() {
  testWidgets('a product is a flat row: no expand chevron, a tap selects it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier)
      ..selectAccount('zt')
      ..selectSection(const SectionId('zentao.bugs'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: ZentaoProductTreeNode(
              account: _account,
              product: _product,
              location: const ToolLocation(section: SectionId('zentao.bugs')),
              openCount: 2,
              isPinned: false,
              onPinToggle: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.chevronRight300), findsNothing);
    expect(find.byIcon(LucideIcons.chevronDown300), findsNothing);

    await tester.tap(find.text('Wallet'));
    await tester.pump();

    expect(container.read(currentToolLocationProvider)?.scopeId, '12');
    expect(container.read(selectedZenTaoProductProvider)?.productId, '12');
  });
}
