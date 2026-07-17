# WorkNexus — Project Engineering Rules

Authoritative engineering rules for this repository. They govern how code is
structured, split, and named. When a change conflicts with a rule, follow the
rule or call out the deviation explicitly.

**Severity:** **MUST** (required) · **SHOULD** (strong default, deviate only
with reason) · **MUST NOT** (prohibited) · **EXCEPTION** (allowed carve-out).

Generated files (`*.g.dart`, `*.freezed.dart`) and `lib/l10n/*` are exempt from
line-count and style rules.

---

## 1. Architecture: Clean Architecture, feature-first

- **1.1 MUST** — Organize by **feature first, layer second**. Each feature is a
  self-contained vertical slice with three layers: `domain/` → `data/` →
  `presentation/`. Do not group by layer at the app level.
- **1.2 MUST — Dependency Rule.** Dependencies point inward only:
  `presentation → domain ← data`. `domain` MUST NOT import Flutter, drift, dio,
  Riverpod, or any other layer.
- **1.3 MUST NOT** — `presentation` imports `data/` directly (datasources,
  repository implementations, DTOs, drift, dio). Presentation depends only on
  `domain` (use cases, interfaces, entities).
- **1.4 MUST** — Standard feature layout:

```
features/<feature>/
├── domain/
│   ├── repositories/   # abstract interfaces (owned by the feature)
│   └── usecases/       # one use case = one job
├── data/
│   ├── models/         # DTOs (JSON / drift rows)
│   ├── datasources/    # drift DAO / dio client
│   ├── mappers/        # DTO ↔ entity
│   └── repositories/   # implementations of the domain interfaces
└── presentation/
    ├── providers/      # Riverpod controllers/providers + state (freezed)
    ├── pages/          # screens
    └── widgets/        # child widgets — one widget (or a small group) per file
```

## 2. Domain layer

- **2.1 MUST** — `entities` and `value_objects` are **pure Dart** (no Flutter,
  drift, dio, or json imports) and immutable (freezed).
- **2.2 MUST** — `repositories/` contains **abstract interfaces only**;
  implementations live in `data/`.
- **2.3 MUST** — Business logic lives in **use cases**. One use case does one
  thing, is named after a verb (`FilterTickets`, `BuildBoard`,
  `ResolveTranslationState`), and returns `Result`/`Failure` instead of throwing.
- **2.4 SHOULD** — Presentation calls **use cases**, not repositories directly.
  **EXCEPTION:** a pure CRUD pass-through may call the repository **interface**
  from a controller — but always through the interface, never an implementation.

## 3. Data layer

- **3.1 MUST** — Repository implementations live in the **owning feature's**
  `data/repositories/`, **one repository per file**.
- **3.2 MUST NOT** — Combine multiple repository implementations into a single
  "god" file (the current `data/local/local_repositories.dart` pattern).
- **3.3 MUST** — DTOs / drift rows MUST NOT leak into domain or presentation.
  Convert at the data boundary via `mappers/`.
- **3.4 MUST** — Infrastructure detail (SQL/drift, HTTP/dio, secure storage)
  stays inside `data/datasources/`.

## 4. Presentation layer

- **4.1 MUST** — State is managed with Riverpod; state objects are immutable
  (freezed).
- **4.2 MUST** — Widgets/pages contain no business logic and make no direct
  DB/HTTP calls — they read state and invoke a controller / use case.
- **4.3 MUST** — `pages/` assemble a screen; `widgets/` are composable/reusable
  UI pieces. Do not stuff an entire screen into one page file.

## 5. Shared kernel (`core/`) — controlled exception

- **5.1 MUST** — `core/` holds cross-cutting concerns only: `theme/` (design
  tokens), `widgets/` (design-system components), `error/`, `util/`,
  `usecase/` (base), `database/` (drift infra), `platform/`.
- **5.2 EXCEPTION** — `core/domain/` MAY hold **entities / value objects shared
  by ≥ 2 features** (e.g. `Ticket`, `Workspace`, `Project`) as a deliberate
  *shared kernel*. It is **not** a dumping ground for every entity.
- **5.3 MUST** — An entity/interface used by **only one feature** lives in that
  feature, not in `core/`.
- **5.4 SHOULD** — Prefer feature ownership of repository interfaces; promote to
  the shared kernel only when ≥ 2 features consume it and no single feature
  clearly owns it. Shared-kernel repository implementations are still split
  **one file per repository** (never a god file).

## 6. UI & widget splitting ⭐

- **6.1 MUST** — A hand-written UI file (page/widget) is **≤ 300 lines**. Warn
  and start splitting around ~250. When a file grows too large, **split it into
  smaller child widgets in their own files** — do not pile many widget classes
  into one file.
- **6.2 MUST** — **Prefer extracting a Widget (class) over a widget-returning
  method** (`Widget _buildXxx()`). A widget class supports `const`, narrows the
  rebuild scope, names the unit clearly, and is testable/reusable. *(This is
  already the repo's de-facto style; it is now the rule.)*
- **6.3 MUST NOT** — Break up `build()` with `Widget _buildXxx()` helper
  methods. If you need to split, create a widget class.
- **6.4 SHOULD — When to extract:** (a) it will be **reused**; (b) a UI block is
  **large/independent** (own rebuild scope or own state); (c) to bring a file
  back under the 300-line limit.
- **6.5 SHOULD — When NOT to extract:** the block is tiny, used once, and
  extracting improves neither readability nor reuse — keep it inline. **Do not
  extract for the sake of extracting.**
- **6.6 MUST** — A child widget used only within one file/feature is **private**
  (`_MyWidget`). If reused across features, make it **public** and move it to
  `core/widgets/`.

## 7. Components & design tokens — no hardcoding

- **7.1 MUST** — Use **components** from `core/widgets/` and **design tokens**
  from `core/theme/` (`app_tokens`, `app_palette`, `semantic`) for colors,
  spacing, radius, and text styles.
- **7.2 MUST NOT** — Hardcode `Color(0x...)` / `Colors.xxx`, magic numbers in
  `EdgeInsets`/`SizedBox`, or inline `TextStyle` in presentation. Pull from
  tokens/theme.
- **7.3 MUST** — User-facing strings go through **l10n** (`app_localizations`),
  never hardcoded literals.
- **7.4 SHOULD** — The second time a UI pattern repeats, extract it into a shared
  component in `core/widgets/`.

## 8. Composition root (DI)

- **8.1 MUST** — There is **one** place that wires implementations to interfaces
  (composition root, e.g. `core/di/` or `app/di/`). It is the **only** place
  allowed to know both `data` and `domain`.
- **8.2 MUST** — Features receive dependencies through **interfaces** (via
  providers); they never construct another layer's implementation themselves.

## 9. Naming & file organization

- **9.1 MUST** — Files are `snake_case` and named for their content
  (`ticket_card.dart`, `build_board.dart`).
- **9.2 SHOULD** — One public class per file (except a small group of private
  child widgets sharing a tight context).
- **9.3 SHOULD** — Non-UI files (data/domain) stay under ~400 lines; beyond that,
  check for merged responsibilities.

## 10. Feature isolation (boundaries between features)

- **10.1 MUST NOT** — Feature A imports feature B's internals (its providers,
  widgets, datasources, or adapters).
- **10.2 MUST** — Cross-feature communication goes only through the **shared
  kernel** (`core/domain`, `core/widgets`) or a **public interface** — never
  through an implementation.
- **10.3 SHOULD** — Utilities used across features move up to `core/` (e.g. a
  shared `statusLabel`), rather than being imported from another feature's file.

## 11. Error handling (Result / Failure)

- **11.1 MUST** — `data/` catches infrastructure exceptions (drift/dio) and maps
  them to `Failure`; exceptions MUST NOT leak up to domain or presentation.
- **11.2 MUST** — Use cases and repositories return `Result<T>` (see
  `core/error/`) and **do not throw across a layer boundary**.
- **11.3 MUST** — Presentation renders an error state from `Failure`. Do not
  swallow errors and do not `print`.

## 12. Async & state (Riverpod 3)

- **12.1 SHOULD** — Model async data with **`AsyncValue` / `AsyncNotifier`**
  (loading/error/data) instead of hand-rolled boolean flags.
- **12.2 MUST** — No business logic inside a provider — providers orchestrate;
  logic lives in use cases.
- **12.3 MUST NOT** — Use `ref.read` in `build()` for values that must be
  reactive (use `watch`); `read` is for callbacks/event handlers only.
- **12.4 SHOULD** — `autoDispose` by default; `keepAlive` only with a clear
  reason.
- **12.5 SHOULD** — Name providers `xxxProvider`; controllers
  `XxxController`/`XxxNotifier`.

## 13. Testing

- **13.1 MUST** — Domain (entities/value objects/use cases) is testable **without
  Flutter**; each use case has a unit test.
- **13.2 MUST** — Mock at the **interface boundary** (repository/datasource) with
  `mocktail`; unit tests touch no real infrastructure.
- **13.3 SHOULD** — Repository implementations are tested with in-memory drift;
  important widgets have widget tests.

## 14. Immutability (freezed 3)

- **14.1 MUST** — Entities and state are freezed and immutable; update via
  `copyWith`, never mutate in place.
- **14.2 SHOULD** — Use sealed/union types for multi-branch state
  (idle/loading/error/data).

## 15. BuildContext across async gaps

- **15.1 MUST** — After an `await`, check `context.mounted` before using the
  context (Navigator, ScaffoldMessenger, showDialog).
- **15.2 MUST NOT** — Suppress `use_build_context_synchronously` with
  `// ignore`.

## 16. Local-first / source of truth

- **16.1 MUST** — The local database (drift) is the **single source of truth**.
  The UI reads from the DB, never directly from the network.
- **16.2 MUST** — Sync/network writes into the DB; presentation reacts to DB
  changes (stream/watch). Do not wire dio → UI directly.
- **16.3 SHOULD** — Optimistic updates flow through the DB.

## 17. Automated enforcement

- **17.1 SHOULD** — Tighten `analysis_options.yaml`: enable
  `prefer_const_constructors`, `avoid_print`, `require_trailing_commas`,
  `use_build_context_synchronously: error`, `sort_child_properties_last`.
- **17.2 OPTIONAL** — Add `custom_lint` / `dart_code_metrics` to auto-enforce the
  line limit (rule 6.1), parameter counts, and widget nesting depth instead of
  relying on manual review.

---

## Appendix A — Current violations / tech debt

Reference for incremental cleanup. Not required to fix immediately; do not add
new violations. **Status column updated after the 2026-07-17 refactor pass**, and
again after the theming pass that split the design system into function-specific
`ThemeExtension`s (A9).

| # | Original state | Rules | Status |
|---|---|---|---|
| A1 | `core/domain/` held single-feature entities/interfaces alongside the shared kernel | 1.1, 5.2, 5.3 | **Mostly done** — moved to owning features: board (`board_model`, `filter_state`, `saved_view`), `connection_repository`, `coding_agent_adapter`, `translation_service`. `Ticket`/`Workspace`/`Project` + other ≥2-feature types stay in `core/domain` per 5.2. **Remaining:** `translation_record` + `translation_repository` (still consumed by legacy `data/fixtures` + `data/local/mappers`; move with the `lib/data` dissolution). |
| A2 | `data/local/local_repositories.dart` was **one file** of 6 repos | 3.1, 3.2 | **Done** — split one-file-per-repo under `data/local/repositories/`; `LocalTranslationRepository` moved to `translation/data/repositories/`. |
| A3 | `task_detail/.../detail_panel.dart` was **1216 lines**, 19 classes | 6.1 | **Done** — split into 12 files under `task_detail/presentation/widgets/` (all ≤173 lines); `_uppercaseLabel` → `SectionLabel` widget. |
| A4 | `sidebar.dart` 660 · `settings_page.dart` 345 · `chrome_bar.dart` 345 · `ticket_actions.dart` 388 | 6.1 | **Done** — all split into child-widget files ≤300 lines. |
| A5 | `agents`, `connections`, `task_detail` have **no use cases**; presentation calls repos/adapters directly | 2.3, 2.4 | **Not addressed** — still open; intertwined with A7 remaining (introduce use cases so presentation stops calling other features' providers). |
| A6 | `board` had **no `data/`**; impl in shared `data/local` | 1.4, 3.1 | **Partial** — `board/domain/` now exists (entities + value objects + use cases). Ticket/Workspace repos are shared-kernel impls (kept in `data/local/repositories/` per 5.4). |
| A7 | `translation → agents/data`, `sync → connections/data`, `task_detail → board + agents + translation` (incl. `show statusLabel`) | 1.3, 10.1 | **Partial** — `statusLabel`/`priorityName` lifted to `core/util/labels.dart` (10.3); `openTicketIdProvider` + `settingsOpenProvider` moved to `core/navigation/` (removed `task_detail→board`, `board→connections`). **Remaining:** `board`/`task_detail` presentation still read `agents`/`translation` providers; `translation→agents/data`; `sync→connections/data`; `ticket_card→task_detail`. Fix via shared-kernel contracts + use cases (with A5). |
| A8 | `Result`/`Failure` under-used; ad-hoc `try/catch` | 11.1–11.3 | **Not addressed** — `settings`/`ticket_actions`/`translation` already use `Result`; broaden it, and drop the `print` in `core/widgets/markdown_text.dart` (11.3). |
| A9 | Hardcoded colors: `detail_panel`, `sidebar`, others | 7.1, 7.2 | **Done** — the monolithic `AppTokens` is split into five function-named `ThemeExtension`s: `AppColors` (semantic roles — `background`/`surface`/`success`/`warning`/`error`/…), `AppTypography` (named text ramp), `AppSpacing`, `AppRadii`, `AppBorders` — read via `context.colors/.typography/.spacing/.radii/.borders`; all built + registered in `core/theme/app_theme.dart`. All 38 call sites migrated; `AppTokens` deleted. Scrim/on-color-ink/workspace-fallback are now palette tokens, `Colors.white`→`onAccent`. No raw `Color(0x…)`/`Colors.*` in presentation except the `Colors.transparent` no-fill sentinel and data-driven `Color(ws.colorValue)`. Inline `TextStyle` + magic spacing/radius replaced by tokens (only the parameterized `markdown_text` rendering primitive keeps caller-supplied sizes). |
