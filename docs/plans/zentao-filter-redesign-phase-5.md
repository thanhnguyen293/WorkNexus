# Plan: zentao-filter-redesign phase 5 — ActiveTokens facet chips

## Context

The removable active-filter chips in the chrome bar (`ActiveTokens`) render one
chip per active filter. Add chips for the four new facet sets (severity, assignee,
bug type, resolution) so a user can see and remove them. Depends on phases 1 & 3
(fields + controller toggles + l10n). Declarative UI — write directly, no TDD.

## Constraints

- NO edits outside `lib/features/board/presentation/widgets/active_tokens.dart`.
- Near-miss (do NOT touch): `filter_popover.dart` (phase 4), `chrome_bar.dart`
  (hosts `ActiveTokens` + the "Clear" affordance — unchanged).
- Labels via `zentao_labels.dart` + l10n; severity dot via `severityColor`
  (rules 7.2, 7.3). No raw colors.
- Escape hatch: if `f.severities`/`f.assignees`/`f.bugTypes`/`f.resolutions` or the
  `ctrl.toggle*` methods or `l.unassigned` are missing → STOP (phases 1/3 not run).

## Steps

### Step 1: imports — `lib/features/board/presentation/widgets/active_tokens.dart`

- Current state (lines ~1–11):
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../../core/di/providers.dart';
  import '../../../../core/theme/app_colors.dart';
  import '../../../../core/theme/app_radii.dart';
  import '../../../../core/theme/app_spacing.dart';
  import '../../../../core/theme/app_typography.dart';
  import '../../../../core/util/labels.dart';
  import '../../../../l10n/app_localizations.dart';
  import '../board_providers.dart';
  ```
- Replace with (add semantic + zentao_labels imports, alphabetically placed):
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../../core/di/providers.dart';
  import '../../../../core/theme/app_colors.dart';
  import '../../../../core/theme/app_radii.dart';
  import '../../../../core/theme/app_spacing.dart';
  import '../../../../core/theme/app_typography.dart';
  import '../../../../core/theme/semantic.dart';
  import '../../../../core/util/labels.dart';
  import '../../../../core/util/zentao_labels.dart';
  import '../../../../l10n/app_localizations.dart';
  import '../board_providers.dart';
  ```

### Step 2: add facet tokens — same file

- Current state (lines ~43–50):
  ```dart
      for (final s in f.statuses)
        _Token(label: statusLabel(l, s), onRemove: () => ctrl.toggleStatus(s)),
      for (final p in f.priorities)
        _Token(
          label: priorityName(l, p),
          onRemove: () => ctrl.togglePriority(p),
        ),
    ];
  ```
- Replace with (append the four facet loops before the closing `];`):
  ```dart
      for (final s in f.statuses)
        _Token(label: statusLabel(l, s), onRemove: () => ctrl.toggleStatus(s)),
      for (final p in f.priorities)
        _Token(
          label: priorityName(l, p),
          onRemove: () => ctrl.togglePriority(p),
        ),
      for (final s in f.severities)
        _Token(
          label: zentaoSeverityLabel(s) ?? '$s',
          dotColor: severityColor(c, s),
          onRemove: () => ctrl.toggleSeverity(s),
        ),
      for (final a in f.assignees)
        _Token(
          label: a.isEmpty ? l.unassigned : a,
          onRemove: () => ctrl.toggleAssignee(a),
        ),
      for (final t in f.bugTypes)
        _Token(
          label: zentaoBugTypeLabel(t) ?? t,
          onRemove: () => ctrl.toggleBugType(t),
        ),
      for (final r in f.resolutions)
        _Token(
          label: zentaoResolutionLabel(r) ?? r,
          onRemove: () => ctrl.toggleResolution(r),
        ),
    ];
  ```
- Convention exemplar: the existing `for (final p in f.priorities) _Token(...)`
  loop right above — same `_Token(label:, dotColor?:, onRemove:)` shape. `c` is
  already defined at the top of `build` (`final c = context.colors;`).
- Verify: `fvm dart analyze lib/features/board/presentation/widgets/active_tokens.dart`
  → expected: "No issues found!", exit 0.

## Final verification

- `make verify` (format + analyze + test) → expected: format makes no unexpected
  churn, "No issues found!", "All tests passed!", exit 0.
- Manual (optional): on a ZenTao bug board, toggle a Severity/Type chip in the
  popover → a matching removable chip appears in the chrome bar; click it or
  "Clear" → it is removed.

## Out of scope

- Do NOT restyle `_Token` or the "Clear" control.
- Do NOT add counts to the active tokens (counts live only in the popover chips).
- Do NOT touch any other widget or provider.
