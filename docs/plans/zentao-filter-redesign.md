# Plan: zentao-filter-redesign — context-aware ZenTao board filters

## Problem

The advanced-filter popover (`FilterPopover`) is one generic control shared by
every view. On a ZenTao **Bug board** (one product) or **Task board** (one
execution) 4 of its 5 groups are dead weight or wrong:

- **Provider** — 4 logos, but only ZenTao is connected.
- **Account** — a single account; a one-option filter narrows nothing.
- **Project** — broken: real names mixed with bare numeric ids (`4, 13, 5…`) and
  `Task`. That is the synthetic `projectId = accountId:${scopeName ?? type.label}`
  leaking to the UI (bug payloads carry `product` as a numeric id with no
  `productName`, so `scopeName` becomes `"4"`).
- **Status** — duplicates the board's own columns.
- **Priority** — the only genuinely useful group.

Meanwhile the returned data carries rich ZenTao-native fields the filter never
uses: `severity`, `type`, `resolution`, `assignedTo`.

## Fix direction

Make the popover **context-aware** and **data-derived**:

1. It reads `viewModeProvider` and, for ZenTao boards, renders only relevant
   groups whose chips are derived from the tickets currently scoped to that
   board (with counts), skipping any group with < 2 distinct values.
2. **Bug board** groups: Assignee · Severity · Priority · Type · Resolution.
   **Task board** groups: Assignee · Priority (tasks carry no severity/type;
   `providerEntity` is null for tasks).
3. **Generic board / List** keeps the existing Provider/Account/Project/Status/
   Priority groups unchanged — there they still make sense.

## Key decisions (settled — executor makes none of these)

- **Facet value encoding** stored in `FilterState`:
  - assignee → the display name, or `''` for unassigned.
  - severity → `Set<int>` (ZenTao 1..4).
  - priority → reuses the existing `Set<Priority>` (facet value = `Priority.name`).
  - bugType / resolution → lowercased ZenTao code (`codeerror`, `fixed`, …).
- **Facet source**: the product/execution-scoped set **before** chip filters, so
  chip options and counts stay stable while toggling (matches the mockup).
- **Drop rule**: a group with fewer than 2 distinct options is omitted.
- **Labels** live in presentation (`zentao_labels.dart` + l10n), not the use
  case — the use case returns raw values only, keeping domain pure.

## Phases (run in order, one executor dispatch each)

| Phase | File | Scope |
|---|---|---|
| 1 | `zentao-filter-redesign-phase-1.md` | `FilterState` fields + `FilterTickets` facet application + domain tests |
| 2 | `zentao-filter-redesign-phase-2.md` | `DeriveBoardFacets` use case + domain tests |
| 3 | `zentao-filter-redesign-phase-3.md` | `board_providers` wiring (scoped provider, facets provider, controller) + l10n keys |
| 4 | `zentao-filter-redesign-phase-4.md` | `FilterPopover` contextual rewrite |
| 5 | `zentao-filter-redesign-phase-5.md` | `ActiveTokens` new facet chips |

Phases 1–3 are additive (nothing changes visually; new fields/providers are
unused until phase 4). Phases compile and test independently.

## Toolchain (fvm-pinned — see `Makefile`)

- Codegen (freezed): `make codegen` (`fvm flutter pub run build_runner build --delete-conflicting-outputs`)
- l10n: `fvm flutter gen-l10n` (pubspec `generate: true`)
- Analyze: `fvm dart analyze`
- Test: `fvm flutter test [path]`
- Everything: `make verify` (format + analyze + test)
