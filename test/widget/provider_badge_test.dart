import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/badges.dart';

/// [ProviderBadge] renders each provider's brand logo (a bundled SVG referenced
/// via flutter_gen) instead of the old GH/GL/JR/ZT text chip. GitHub/GitLab/Jira
/// are monochrome marks tinted to their brand color; ZenTao is a full-color
/// recreation of its whirlpool logo.
void main() {
  Future<void> pumpBadge(WidgetTester tester, ProviderType provider) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(body: Center(child: ProviderBadge(provider))),
      ),
    );
  }

  testWidgets('every provider renders its brand SVG logo, not a code label', (
    tester,
  ) async {
    for (final p in ProviderType.values) {
      await pumpBadge(tester, p);
      expect(find.byType(SvgPicture), findsOneWidget, reason: '${p.name} logo');
      // The old 2-letter code chip (GH/GL/JR/ZT) is gone.
      expect(find.text(p.code), findsNothing, reason: '${p.name} code text');
    }
  });

  test('every brand SVG asset is bundled and is valid SVG markup', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in const ['github', 'gitlab', 'jira', 'zentao']) {
      final svg = await rootBundle.loadString('assets/brands/$name.svg');
      expect(svg, contains('<svg'), reason: '$name.svg is real SVG markup');
      expect(svg, contains('<path'), reason: '$name.svg has a drawable path');
    }
  });
}
