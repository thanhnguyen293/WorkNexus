import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../platform/app_icon_providers.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_icon_button.dart';
import 'app_snack.dart';

/// The picture the app shows as its icon, with a button to pick another image
/// and one to go back to the app's own.
class QuickSettingsAppIconControl extends ConsumerWidget {
  const QuickSettingsAppIconControl({super.key});

  static const _imageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'ico',
  ];

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final images = XTypeGroup(
      label: AppL10n.of(context).appIconImages,
      extensions: _imageExtensions,
    );
    final file = await openFile(acceptedTypeGroups: [images]);
    if (file == null) return;
    final done = await ref.read(appIconProvider.notifier).choose(file.path);
    if (!done && context.mounted) {
      showAppSnack(context, AppL10n.of(context).appIconInvalid, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final custom = ref.watch(appIconProvider).asData?.value;
    final size = context.sizes.controlMd;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.md),
          child: SizedBox.square(
            dimension: size,
            child: custom == null
                ? Image.asset('assets/tray/app_icon_256.png')
                : Image.file(custom, key: ValueKey<String>(custom.path)),
          ),
        ),
        SizedBox(width: context.spacing.md),
        Flexible(
          child: AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: () => _choose(context, ref),
            child: Text(l.appIconChoose, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (custom != null) ...[
          SizedBox(width: context.spacing.xs),
          AppIconButton(
            icon: LucideIcons.rotateCcw300,
            tooltip: l.appIconReset,
            size: AppIconButtonSize.small,
            onPressed: () => ref.read(appIconProvider.notifier).reset(),
          ),
        ],
      ],
    );
  }
}
