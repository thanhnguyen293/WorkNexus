// Re-vendors phosphor_flutter 2.1.0 from the pub cache with the WorkNexus
// final-IconData patch applied (see PATCH.md).
//
//   node packages/phosphor_flutter/tool/vendor.mjs <pub-cache>/hosted/pub.dev/phosphor_flutter-2.1.0
//
// Copies LICENSE, CHANGELOG.md, README.md and lib/ (fonts + sources), then
// rewrites the generated icon constants as plain `IconData` and extracts the
// duotone secondary glyphs into a const lookup table. example/ and meta/
// (screenshots) are left out. pubspec.yaml and PATCH.md are maintained by hand.

import { copyFileSync, cpSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const src = process.argv[2];
if (!src) {
  console.error('usage: node vendor.mjs <path to phosphor_flutter-2.1.0>');
  process.exit(64);
}
const dest = join(dirname(fileURLToPath(import.meta.url)), '..');

for (const f of ['LICENSE', 'CHANGELOG.md', 'README.md']) {
  copyFileSync(join(src, f), join(dest, f));
}
cpSync(join(src, 'lib'), join(dest, 'lib'), { recursive: true });

const srcDir = join(dest, 'lib', 'src');
const iconData = (code, style) =>
  `IconData(0x${code}, fontFamily: 'Phosphor${style}', ` +
  `fontPackage: 'phosphor_flutter', matchTextDirection: true)`;

const rewrite = (file, transform) => {
  const path = join(srcDir, file);
  const out = transform(readFileSync(path, 'utf8').replace(/\r\n/g, '\n'));
  for (const leftover of ['PhosphorFlatIconData(', 'PhosphorIconData(']) {
    if (out.includes(leftover)) throw new Error(`${file}: unpatched ${leftover}`);
  }
  writeFileSync(path, out);
};

const flat = (s) => {
  let n = 0;
  const out = s.replace(
    /PhosphorFlatIconData\(0x([0-9a-f]+), '([A-Za-z]+)'\)/g,
    (_, code, st) => (n++, iconData(code, st)),
  );
  return [out, n];
};

const dataImport =
  "import 'package:phosphor_flutter/src/phosphor_icon_data.dart';\n";

for (const style of ['regular', 'thin', 'light', 'bold', 'fill']) {
  rewrite(`phosphor_icons_${style}.dart`, (s) => {
    // Plain IconData constants no longer reference phosphor_icon_data.dart.
    const [out, n] = flat(s.replace(dataImport, ''));
    console.log(`${style}: ${n} icons`);
    return out;
  });
}

// Duotone glyphs carry a secondary layer, except a few single-layer ones
// (e.g. cellSignalNone, wifiNone) that are flat icons in the duotone font.
const secondaries = [];
rewrite('phosphor_icons_duotone.dart', (s) => {
  const [out, n] = flat(
    s.replace(
      /PhosphorDuotoneIconData\(\s*0x([0-9a-f]+),\s*PhosphorIconData\(0x([0-9a-f]+), 'Duotone'\),?\s*\)/g,
      (_, primary, secondary) => {
        secondaries.push([primary, secondary]);
        return `PhosphorDuotoneIconData(${iconData(primary, 'Duotone')})`;
      },
    ),
  );
  console.log(`duotone: ${secondaries.length} two-layer + ${n} flat icons`);
  return out;
});

// Values are const IconData (not bare code points) so release builds can still
// tree-shake the icon fonts: IconData.codePoint must be a constant.
writeFileSync(
  join(srcDir, 'phosphor_duotone_secondaries.dart'),
  `// Auto generated File (packages/phosphor_flutter/tool/vendor.mjs)
// DON'T EDIT BY HAND

import 'package:flutter/widgets.dart';

/// Duotone primary glyph code point -> its translucent secondary layer.
const Map<int, IconData> phosphorDuotoneSecondaries = <int, IconData>{
${secondaries.map(([p, s]) => `  0x${p}: ${iconData(s, 'Duotone')},`).join('\n')}
};
`,
);

writeFileSync(
  join(srcDir, 'phosphor_icon_data.dart'),
  `library phosphor_flutter;

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/src/phosphor_duotone_secondaries.dart';

// WorkNexus patch (see PATCH.md): Flutter 3.44 made IconData a final class, so
// the original \`PhosphorIconData extends IconData\` no longer compiles. Every
// Phosphor glyph is now a plain IconData; the old names remain as aliases.

/// A Phosphor icon glyph.
typedef PhosphorIconData = IconData;

/// A single-layer Phosphor icon glyph.
typedef PhosphorFlatIconData = IconData;

/// A two-layer duotone glyph: this is the primary layer, drawn by
/// [PhosphorIcon] over the translucent [secondary] layer.
extension type const PhosphorDuotoneIconData(IconData primary)
    implements IconData {
  /// Extension types are erased at runtime, so \`is PhosphorDuotoneIconData\`
  /// cannot tell a duotone glyph apart; this checks the glyph itself.
  static bool isDuotone(IconData icon) =>
      icon.fontFamily == 'PhosphorDuotone' &&
      icon.fontPackage == 'phosphor_flutter' &&
      phosphorDuotoneSecondaries.containsKey(icon.codePoint);

  /// The translucent background layer of this glyph.
  IconData get secondary => phosphorDuotoneSecondaries[codePoint]!;
}
`,
);

rewrite('phosphor_icon.dart', (s) => {
  const before = `    if (icon is PhosphorDuotoneIconData) {
      final duotoneIcon = icon as PhosphorDuotoneIconData;`;
  const after = `    final icon = this.icon;
    if (icon != null && PhosphorDuotoneIconData.isDuotone(icon)) {
      final duotoneIcon = PhosphorDuotoneIconData(icon);`;
  if (!s.includes(before)) throw new Error('phosphor_icon.dart: duotone check not found');
  return s.replace(before, after);
});
console.log('patched phosphor_icon.dart');
