# Quick Settings Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the title-bar language toggle with an anchored Quick Settings popover containing language and all existing appearance settings, and remove appearance settings from Integrations.

**Architecture:** `TitleBar` hosts a reusable `QuickSettingsButton` from `core/widgets`. The button owns local overlay/focus state, while a separate Riverpod `QuickSettingsPanel` watches and updates `appSettingsProvider`; the existing controller and Drift persistence path remain unchanged.

**Tech Stack:** Flutter 3.38, Dart 3.10, Riverpod 3, Flutter localization/ARB, flutter_test.

## Global Constraints

- Keep every hand-written UI file at or below 300 lines.
- Use only `AppColors`, `AppTypography`, `AppSpacing`, `AppRadii`, and `AppBorders` for presentation styling.
- Put every new visible label and tooltip in both ARB localization catalogs.
- Keep popover open after a setting changes; close it on outside click, Escape, or a second trigger click.
- Do not change `AppSettingsController`, `settingsPersistProvider`, or the Drift settings schema.
- Do not refactor unrelated Integration, sync, board, or task-detail code.

---

### Task 1: Localize Quick Settings labels

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_vi.arb`
- Generate: `lib/l10n/app_localizations.dart`
- Generate: `lib/l10n/app_localizations_en.dart`
- Generate: `lib/l10n/app_localizations_vi.dart`

**Interfaces:**
- Produces: `AppL10n.quickSettings`, `appearance`, `language`, `english`, `theme`, `themeLight`, `themeDark`, `themeMidnight`, `surface`, `surfaceFlat`, `surfaceOutline`, `density`, `densityComfortable`, `densityCompact`, `companyTint`, `settingOff`, `settingOn`, `font`, and `chooseUiFont`.

- [ ] **Step 1: Add English labels**

Append these entries after `clearAllFilters` in `lib/l10n/app_en.arb`, adding the required comma before them:

```json
  "clearAllFilters": "Clear all filters",
  "quickSettings": "Quick settings",
  "appearance": "Appearance",
  "language": "Language",
  "english": "English",
  "theme": "Theme",
  "themeLight": "Light",
  "themeDark": "Dark",
  "themeMidnight": "Midnight",
  "surface": "Surface",
  "surfaceFlat": "Flat",
  "surfaceOutline": "Outline",
  "density": "Density",
  "densityComfortable": "Comfortable",
  "densityCompact": "Compact",
  "companyTint": "Company tint",
  "settingOff": "Off",
  "settingOn": "On",
  "font": "Font",
  "chooseUiFont": "Choose UI font"
```

- [ ] **Step 2: Add Vietnamese labels**

Append these entries after `clearAllFilters` in `lib/l10n/app_vi.arb`, adding the required comma before them:

```json
  "clearAllFilters": "Xóa tất cả bộ lọc",
  "quickSettings": "Cài đặt nhanh",
  "appearance": "Giao diện",
  "language": "Ngôn ngữ",
  "english": "Tiếng Anh",
  "theme": "Chủ đề",
  "themeLight": "Sáng",
  "themeDark": "Tối",
  "themeMidnight": "Nửa đêm",
  "surface": "Bề mặt",
  "surfaceFlat": "Phẳng",
  "surfaceOutline": "Viền",
  "density": "Mật độ",
  "densityComfortable": "Thoải mái",
  "densityCompact": "Gọn",
  "companyTint": "Màu công ty",
  "settingOff": "Tắt",
  "settingOn": "Bật",
  "font": "Phông chữ",
  "chooseUiFont": "Chọn phông chữ giao diện"
```

- [ ] **Step 3: Regenerate localization classes**

Run:

```bash
fvm flutter gen-l10n
```

Expected: exit 0; the three generated localization files expose all getters listed under **Interfaces**.

- [ ] **Step 4: Verify generated localization output**

Run:

```bash
rg -n "String get (quickSettings|chooseUiFont|densityCompact)" lib/l10n/app_localizations*.dart
```

Expected: getter declarations in `app_localizations.dart` and implementations in both locale subclasses.

- [ ] **Step 5: Commit localization changes**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_vi.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_vi.dart
git commit -m "feat: localize quick settings"
```

### Task 2: Add the anchored Quick Settings popover

**Files:**
- Create: `test/widget/quick_settings_test.dart`
- Create: `lib/core/widgets/quick_settings_button.dart`
- Create: `lib/core/widgets/quick_settings_panel.dart`
- Modify: `lib/app/shell/title_bar.dart`

**Interfaces:**
- `QuickSettingsButton extends StatefulWidget`: public title-bar trigger; no constructor arguments.
- `QuickSettingsPanel extends ConsumerWidget`: public reactive popover body; no constructor arguments.
- Widget keys: `quick-settings-trigger` and `quick-settings-panel`.
- Consumes: `appSettingsProvider` and the localized getters from Task 1.

- [ ] **Step 1: Write failing popover widget tests**

Create `test/widget/quick_settings_test.dart` with a Riverpod/Material harness following `test/widget/add_connection_dialog_test.dart`. The complete initial test file is:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/title_bar.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpTitleBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SettingsHarness(child: TitleBar()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openQuickSettings(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-settings-trigger')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title bar opens all quick settings from one trigger', (
    tester,
  ) async {
    await pumpTitleBar(tester);

    expect(find.text('EN'), findsNothing);
    expect(find.text('VI'), findsNothing);
    await openQuickSettings(tester);

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
    for (final label in <String>[
      'Quick settings',
      'Language',
      'Appearance',
      'Theme',
      'Surface',
      'Density',
      'Company tint',
      'Font',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('language changes immediately and keeps the popover open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).locale.languageCode, 'vi');
    expect(find.text('Cài đặt nhanh'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('appearance changes immediately and keeps the popover open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      container.read(appSettingsProvider).variant,
      AppThemeVariant.dark,
    );
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('outside click closes the quick settings popover', (tester) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('second trigger click closes the quick settings popover', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    final trigger = find.byKey(
      const ValueKey<String>('quick-settings-trigger'),
    );
    await tester.tapAt(tester.getCenter(trigger));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('Escape closes the quick settings popover', (tester) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });
}

class _SettingsHarness extends ConsumerWidget {
  const _SettingsHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      locale: settings.locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: settings.variant,
        surface: settings.surface,
        density: settings.density,
        fontFamily: settings.fontFamily,
      ),
      home: Scaffold(body: child),
    );
  }
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
fvm flutter test test/widget/quick_settings_test.dart
```

Expected: FAIL because `quick-settings-trigger` does not exist and the old `EN`/`VI` toggle is still visible.

- [ ] **Step 3: Create the reactive popover body**

Create `lib/core/widgets/quick_settings_panel.dart`. Implement one public `QuickSettingsPanel` and private `_SectionLabel`, `_SegmentedControl<T>`, and `_FontControl` widget classes. Its `build` method must watch `appSettingsProvider`, use `AppL10n.of(context)`, and construct these exact bindings:

```dart
_SegmentedControl<String>(
  label: l.language,
  value: settings.locale.languageCode,
  options: {'en': l.english, 'vi': l.vietnamese},
  onChanged: controller.setLanguageCode,
),
_SectionLabel(l.appearance),
_SegmentedControl<AppThemeVariant>(
  label: l.theme,
  value: settings.variant,
  options: {
    AppThemeVariant.light: l.themeLight,
    AppThemeVariant.dark: l.themeDark,
    AppThemeVariant.midnight: l.themeMidnight,
  },
  onChanged: controller.setVariant,
),
_SegmentedControl<SurfaceStyle>(
  label: l.surface,
  value: settings.surface,
  options: {
    SurfaceStyle.flat: l.surfaceFlat,
    SurfaceStyle.outline: l.surfaceOutline,
  },
  onChanged: controller.setSurface,
),
_SegmentedControl<AppDensity>(
  label: l.density,
  value: settings.density,
  options: {
    AppDensity.comfortable: l.densityComfortable,
    AppDensity.compact: l.densityCompact,
  },
  onChanged: controller.setDensity,
),
_SegmentedControl<bool>(
  label: l.companyTint,
  value: settings.companyTint,
  options: {false: l.settingOff, true: l.settingOn},
  onChanged: controller.setCompanyTint,
),
_FontControl(
  label: l.font,
  tooltip: l.chooseUiFont,
  value: settings.fontFamily,
  onChanged: controller.setFontFamily,
),
```

Wrap the controls in a container keyed with
`ValueKey<String>('quick-settings-panel')`. Follow the popover styling exemplar
in `lib/features/board/presentation/widgets/filter_popover.dart`: width no more
than 340, height no more than 500 and the available window height, `c.surface`,
`context.radii.lg`, `c.borderStrong`, and its token-derived shadow. Use
`SingleChildScrollView` and vertical gaps from `context.spacing`.

Use `TextButton` for each segmented option so it is keyboard focusable. Style
the selected option with `c.selectionFill` and `c.accent`, the unselected option
with `c.surfaceSubtle` and `c.textSecondary`, and use token padding/radii. Port
the existing font menu behavior from `lib/core/theme/appearance_controls.dart`,
but replace all hardcoded labels/tooltips with the parameters above.

- [ ] **Step 4: Create the anchored overlay trigger**

Create `lib/core/widgets/quick_settings_button.dart` with:

```dart
class QuickSettingsButton extends StatefulWidget {
  const QuickSettingsButton({super.key});

  @override
  State<QuickSettingsButton> createState() => _QuickSettingsButtonState();
}
```

The private state owns exactly one `OverlayPortalController`, `LayerLink`,
trigger `FocusNode`, and panel `FocusNode`. Build an `OverlayPortal` whose child
is a `CompositedTransformTarget` wrapping this trigger:

```dart
IconButton(
  key: const ValueKey<String>('quick-settings-trigger'),
  focusNode: _triggerFocusNode,
  tooltip: AppL10n.of(context).quickSettings,
  onPressed: _toggle,
  icon: const Icon(Icons.tune),
)
```

The overlay builder returns a full-screen `Stack` with a dismissible
`ModalBarrier` first and a `Positioned(left: 0, top: 0)`
`CompositedTransformFollower` second. Configure the follower with:

```dart
link: _layerLink,
showWhenUnlinked: false,
targetAnchor: Alignment.bottomRight,
followerAnchor: Alignment.topRight,
offset: Offset(0, context.spacing.xs),
child: Focus(
  focusNode: _panelFocusNode,
  onKeyEvent: _handlePanelKeyEvent,
  child: const QuickSettingsPanel(),
),
```

`_toggle` shows/hides the controller. After showing, request panel focus in a
post-frame callback. `_handlePanelKeyEvent` handles only a `KeyDownEvent` whose
logical key is `LogicalKeyboardKey.escape`, hides the overlay, restores trigger
focus, and returns `KeyEventResult.handled`; otherwise return `ignored`.
`ModalBarrier.onDismiss` uses the same hide-and-restore-focus method. Dispose
both focus nodes.

- [ ] **Step 5: Replace the title-bar language toggle**

In `lib/app/shell/title_bar.dart`:

- Remove the `app_settings.dart` import and add
  `../../core/widgets/quick_settings_button.dart`.
- Remove `final settings = ref.watch(appSettingsProvider);`.
- Replace `_LangToggle(...)` with `const QuickSettingsButton()`.
- Delete the complete `_LangToggle` private widget.
- Update the title-bar doc comment to say it hosts sync status and Quick
  Settings.

Keep `TitleBar` as a `ConsumerWidget` in this task to avoid unrelated class
refactoring.

- [ ] **Step 6: Format and run the popover tests**

Run:

```bash
fvm dart format lib/core/widgets/quick_settings_button.dart lib/core/widgets/quick_settings_panel.dart lib/app/shell/title_bar.dart test/widget/quick_settings_test.dart
fvm flutter test test/widget/quick_settings_test.dart
```

Expected: formatting exits 0; all six widget tests PASS with no Flutter exceptions or overflow diagnostics.

- [ ] **Step 7: Commit the popover**

```bash
git add lib/core/widgets/quick_settings_button.dart lib/core/widgets/quick_settings_panel.dart lib/app/shell/title_bar.dart test/widget/quick_settings_test.dart
git commit -m "feat: add quick settings popover"
```

### Task 3: Remove appearance controls from Integrations

**Files:**
- Modify: `test/widget/quick_settings_test.dart`
- Modify: `lib/features/connections/presentation/settings_page.dart`
- Delete: `lib/core/theme/appearance_controls.dart`

**Interfaces:**
- Consumes: `_SettingsHarness` already defined in Task 2.
- Produces: `SettingsPage` with integration/account content only.

- [ ] **Step 1: Add a failing location test**

Add this import to `test/widget/quick_settings_test.dart`:

```dart
import 'package:work_nexus/features/connections/presentation/settings_page.dart';
```

Add this test before the closing brace of `main()`:

```dart
testWidgets('Integrations page no longer contains appearance settings', (
  tester,
) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const _SettingsHarness(child: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Connected accounts'), findsOneWidget);
  expect(find.text('Appearance'), findsNothing);
});
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
fvm flutter test test/widget/quick_settings_test.dart --plain-name "Integrations page no longer contains appearance settings"
```

Expected: FAIL because `SettingsPage` still renders the `Appearance` heading.

- [ ] **Step 3: Remove the old Integration-page section**

In `lib/features/connections/presentation/settings_page.dart`, remove the
`appearance_controls.dart` import and delete this exact tail from the main
column:

```dart
SizedBox(height: context.spacing.xl5),
Container(height: 1, color: c.border),
SizedBox(height: context.spacing.xl4),
_uppercase(context, 'Appearance'),
SizedBox(height: context.spacing.xl),
const AppearanceControls(),
```

Do not remove `_uppercase`; `_ProviderPicker` still uses it for the localized
provider heading.

- [ ] **Step 4: Delete the obsolete appearance widget**

Delete `lib/core/theme/appearance_controls.dart` after confirming with:

```bash
rg -n "appearance_controls|AppearanceControls" lib test
```

Expected before deletion: only the file's own declarations; expected after deletion: no matches.

- [ ] **Step 5: Format and verify the location change**

Run:

```bash
fvm dart format lib/features/connections/presentation/settings_page.dart test/widget/quick_settings_test.dart
fvm flutter test test/widget/quick_settings_test.dart
```

Expected: all seven Quick Settings widget tests PASS.

- [ ] **Step 6: Commit the Integration cleanup**

```bash
git add lib/features/connections/presentation/settings_page.dart lib/core/theme/appearance_controls.dart test/widget/quick_settings_test.dart
git commit -m "refactor: move appearance settings out of integrations"
```

### Task 4: Verify architecture and regressions

**Files:** No production edits expected. If a verification failure requires a code change, edit only a file already listed above and rerun its targeted test first.

- [ ] **Step 1: Enforce file-size and boundary rules**

Run:

```bash
wc -l lib/core/widgets/quick_settings_button.dart lib/core/widgets/quick_settings_panel.dart lib/app/shell/title_bar.dart lib/features/connections/presentation/settings_page.dart
rg -n "features/|data/" lib/core/widgets/quick_settings_*.dart
```

Expected: every UI file is at most 300 lines; the boundary search returns no matches.

- [ ] **Step 2: Run static analysis**

Run:

```bash
fvm dart analyze
```

Expected: exit 0 with `No issues found!`.

- [ ] **Step 3: Run the focused test suite**

Run:

```bash
fvm flutter test test/widget/quick_settings_test.dart
```

Expected: all seven tests PASS.

- [ ] **Step 4: Run the full regression suite**

Run:

```bash
fvm flutter test
```

Expected: exit 0; all project tests PASS with no exceptions, overflows, or warnings.

- [ ] **Step 5: Inspect the final diff**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` exits 0; status contains only the intended Quick Settings files if verification required any post-commit fixes, otherwise it is clean apart from unrelated pre-existing untracked files.
