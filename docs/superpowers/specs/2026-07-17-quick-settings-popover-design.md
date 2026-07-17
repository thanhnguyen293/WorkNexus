# Quick Settings Popover Design

## Goal

Move the application-wide appearance controls out of the Integrations page and
combine them with the language selector in one compact Quick Settings popover.
The entry point is always available at the top-right of the application title
bar.

## Scope

The Quick Settings popover contains the settings that already exist:

- Language: English and Vietnamese.
- Theme: light, dark, and midnight.
- Surface: flat and outline.
- Density: comfortable and compact.
- Company tint: on and off.
- UI font: the existing font choices.

This change does not add new settings, change persistence, or redesign the
Integrations account-management flow.

## User Experience

The current EN/VI control in the title bar is replaced by a Quick Settings icon
button. Selecting it opens a compact popover below the icon, aligned to its
right edge so it remains anchored in the top-right corner.

The popover presents a localized heading followed by the language and
appearance controls. A setting is applied and persisted immediately. The
popover stays open after a selection so several settings can be adjusted in one
visit. It closes when the user selects the icon again, clicks outside it, or
presses Escape.

The icon has a localized tooltip and semantic label. Keyboard users can focus
the trigger, open the popover, navigate its controls, and dismiss it with
Escape. The popover is constrained to the available window area and uses a
compact, vertically arranged layout rather than the wide wrapping layout from
the Integrations page.

## Component Design

`TitleBar` owns the placement of a new public `QuickSettingsButton`. The button
and its popover live under `core/widgets/` because they expose app-wide settings
and are not owned by the Connections feature.

The anchored presentation uses Flutter's overlay primitives with a linked
target/follower pair. The overlay content remains a Riverpod consumer so active
values and labels react immediately when the theme or locale changes. Opening,
closing, outside-click handling, and Escape dismissal are local presentation
state; no global provider is introduced.

The current appearance controls are adapted into focused widget classes that
can render in the compact popover. They continue to call
`AppSettingsController` intent methods and never access persistence directly.
All colors, spacing, radii, borders, and typography come from the existing
theme extensions. Every visible label and tooltip is added to both localization
catalogs.

The Appearance section and its divider are removed from `SettingsPage`. The
page then contains only integration/account concerns. The existing language
toggle classes are removed from `TitleBar`; the sync indicator remains
unchanged.

## Data Flow

1. The user opens `QuickSettingsButton` in the title bar.
2. The popover watches `appSettingsProvider` and renders current selections.
3. Selecting a value invokes the matching `AppSettingsController` method.
4. The controller updates state and uses the existing
   `settingsPersistProvider` callback.
5. `WorkNexusApp` rebuilds with the selected theme or locale, while the popover
   reflects the new selection.

There is no new domain or data-layer behavior. The existing settings row in
Drift remains the source of persisted preferences.

## Failure Handling

Quick Settings introduces no asynchronous operation or new failure mode.
Persistence retains its current behavior. Overlay teardown is tied to the
widget lifecycle so no entry remains after the title bar is disposed.

## Testing

Widget tests will verify that:

- The title bar exposes a Quick Settings trigger instead of the inline language
  toggle.
- Activating the trigger shows every language and appearance setting.
- Choosing a language updates `appSettingsProvider` and the visible localized
  content.
- Choosing an appearance value updates the provider while the popover remains
  open.
- Clicking outside or pressing Escape closes the popover.
- `SettingsPage` no longer displays the Appearance section.

Existing settings persistence and theme-extension tests remain unchanged and
must continue to pass. The implementation will be formatted, analyzed, and
verified with the relevant Flutter widget tests followed by the full test suite.

## Acceptance Criteria

- One Quick Settings icon is always visible at the right end of the title bar.
- Its compact popover is anchored below and right-aligned with the icon.
- Language and all existing appearance controls are available in the popover.
- Changes apply and persist immediately without closing the popover.
- Outside click, Escape, and a second trigger click dismiss the popover.
- Integrations no longer contains appearance or language settings.
- The implementation follows WorkNexus design-token, localization, widget
  splitting, and Riverpod rules.
