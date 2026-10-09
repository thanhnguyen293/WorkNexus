# Vendored phosphor_flutter 2.1.0 — WorkNexus patch

Upstream `phosphor_flutter` 2.1.0 (May 2024, MIT — see `LICENSE`) is the latest
release and no longer compiles on Flutter 3.44+, where `IconData` became a
`final class`: its `PhosphorIconData extends IconData` is now illegal. Fixes are
open upstream but unmerged (phosphor-icons/flutter#62, #63, #66, issue #64).
Remove this vendored copy and go back to the pub.dev package once a release
supports final `IconData`.

## What changed

- `PhosphorIconData` and `PhosphorFlatIconData` are typedefs of `IconData`.
  Every generated constant (`PhosphorIconsLight.x`, `PhosphorIconsFill.x`, …) is
  a plain `const IconData(...)` with the same code point, font family
  (`Phosphor<Style>`), font package and `matchTextDirection: true` as before.
- `PhosphorDuotoneIconData` is an extension type over `IconData`. The secondary
  layer can no longer live in a field, so `secondary` reads it (a const
  `IconData`, which keeps icon-font tree-shaking working) from the generated
  `phosphorDuotoneSecondaries` table (`lib/src/phosphor_duotone_secondaries.dart`).
- `PhosphorIcon` detects duotone glyphs with `PhosphorDuotoneIconData.isDuotone`
  instead of an `is` check (extension types are erased at runtime).
- `example/` and `meta/` (screenshots) are not vendored.

Public names and call sites are unchanged.

## Re-vendoring

`lib/`, `LICENSE`, `CHANGELOG.md` and `README.md` are produced by the script
below; `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` and this file are
maintained by hand.

```bash
node packages/phosphor_flutter/tool/vendor.mjs <pub-cache>/hosted/pub.dev/phosphor_flutter-2.1.0
```
