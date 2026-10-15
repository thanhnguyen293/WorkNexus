import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_icon_picker.dart';
import 'mini_app_permissions_section.dart';

/// Adds a mini app (a web address and an optional name; its icon comes from
/// the site), or — given [existing] — edits one, with its icon too.
class MiniAppDialog extends ConsumerStatefulWidget {
  const MiniAppDialog({super.key, this.existing});

  final MiniApp? existing;

  static Future<void> show(BuildContext context, {MiniApp? existing}) =>
      showDialog<void>(
        context: context,
        builder: (_) => MiniAppDialog(existing: existing),
      );

  @override
  ConsumerState<MiniAppDialog> createState() => _MiniAppDialogState();
}

class _MiniAppDialogState extends ConsumerState<MiniAppDialog> {
  late final _url = TextEditingController(text: widget.existing?.url);
  late final _name = TextEditingController(text: widget.existing?.name);
  late String? _iconPath = widget.existing?.iconPath;
  String? _error;
  bool _saving = false;
  bool _iconBusy = false;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_url.text.trim().isEmpty || _saving) return;
    final navigator = Navigator.of(context);
    final l = AppL10n.of(context);
    final existing = widget.existing;
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(miniAppControllerProvider.notifier);
    final res = existing == null
        ? await controller.add(url: _url.text, name: _name.text)
        : await controller.update(
            app: existing,
            url: _url.text,
            name: _name.text,
            iconPath: _iconPath,
          );
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        if (existing == null) {
          ref.read(appNavProvider.notifier).showMiniApp(value.id);
        }
        navigator.pop();
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure is ParseFailure
              ? l.miniAppInvalidUrl
              : l.actionFailed(failure.message);
        });
    }
  }

  /// Runs an icon change, keeping the dialog open and showing its failure
  /// inline.
  Future<void> _changeIcon(Future<Result<String?>> Function() run) async {
    final failed = AppL10n.of(context).miniAppIconFailed;
    setState(() {
      _iconBusy = true;
      _error = null;
    });
    final res = await run();
    if (!mounted) return;
    setState(() {
      _iconBusy = false;
      switch (res) {
        case Ok(:final value):
          if (value != null) {
            _iconPath = value;
          } else {
            _error = failed;
          }
        case Err():
          _error = failed;
      }
    });
  }

  Future<void> _choose(MiniApp app) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'ico'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    await _changeIcon(
      () => ref
          .read(miniAppControllerProvider.notifier)
          .importIcon(app.id, file.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final existing = widget.existing;
    return AppDialogFrame(
      title: existing == null ? l.miniAppAdd : l.miniAppEdit,
      leadingIcon: LucideIcons.appWindow300,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _saving,
          onPressed: _url.text.trim().isEmpty || _saving || _iconBusy
              ? null
              : _save,
          child: Text(l.save),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: s.xl,
          children: [
            ConnectionTextField(
              label: l.miniAppUrlLabel,
              hint: l.miniAppUrlHint,
              controller: _url,
              autofocus: true,
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
            ConnectionTextField(
              label: l.miniAppNameLabel,
              controller: _name,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            if (existing != null)
              MiniAppIconPicker(
                name: _name.text,
                iconPath: _iconPath,
                busy: _iconBusy,
                onChoose: () => _choose(existing),
                onUseSite: () => _changeIcon(
                  () => ref
                      .read(miniAppControllerProvider.notifier)
                      .fetchSiteIcon(existing.id, _url.text),
                ),
              ),
            if (existing != null)
              MiniAppPermissionsSection(miniAppId: existing.id),
          ],
        ),
      ),
    );
  }
}
