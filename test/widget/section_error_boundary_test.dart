import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/section_error_boundary.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_state_view.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Widget _buildWrapper(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildAppTheme(
      variant: AppThemeVariant.dark,
      surface: SurfaceStyle.flat,
      density: AppDensity.comfortable,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SectionErrorBoundary', () {
    testWidgets('renders child normally when there is no error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          const SectionErrorBoundary(child: Text('Normal Content')),
        ),
      );

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.byType(AppStateView), findsNothing);
    });

    testWidgets('displays AppStateView.error when captureError is called', (
      tester,
    ) async {
      final boundaryKey = GlobalKey<SectionErrorBoundaryState>();
      var retryCalled = false;

      await tester.pumpWidget(
        _buildWrapper(
          SectionErrorBoundary(
            key: boundaryKey,
            title: 'Something went wrong',
            message: 'Custom error detail',
            onRetry: () => retryCalled = true,
            child: const Text('Child Content'),
          ),
        ),
      );

      expect(find.text('Child Content'), findsOneWidget);

      boundaryKey.currentState!.captureError(Exception('Crash'));
      await tester.pump();

      expect(find.text('Child Content'), findsNothing);
      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Custom error detail'), findsOneWidget);

      // Find retry button
      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(retryCalled, isTrue);
      // Once retried, child is re-rendered
      expect(find.text('Child Content'), findsOneWidget);
      expect(find.byType(AppStateView), findsNothing);
    });

    testWidgets('uses exception text when message is omitted', (tester) async {
      final boundaryKey = GlobalKey<SectionErrorBoundaryState>();

      await tester.pumpWidget(
        _buildWrapper(
          SectionErrorBoundary(
            key: boundaryKey,
            child: const Text('Child Content'),
          ),
        ),
      );

      boundaryKey.currentState!.captureError('Network socket failed');
      await tester.pump();

      expect(find.text('Network socket failed'), findsOneWidget);
    });
  });
}
