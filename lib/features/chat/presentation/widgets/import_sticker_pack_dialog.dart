import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/parse_sticker_pack_link.dart';
import '../providers/sticker_import_jobs.dart';
import '../providers/sticker_providers.dart';

/// Starts importing a Telegram sticker set from its link, asking for the bot
/// token the first time (it is kept for next time). It waits only until
/// Telegram has listed the set — so a bad link or token is said here — and
/// leaves the import to go on in the background. Resolves to the set's
/// title, or null when closed.
class ImportStickerPackDialog extends ConsumerStatefulWidget {
  const ImportStickerPackDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const ImportStickerPackDialog(),
  );

  @override
  ConsumerState<ImportStickerPackDialog> createState() =>
      _ImportStickerPackDialogState();
}

class _ImportStickerPackDialogState
    extends ConsumerState<ImportStickerPackDialog> {
  final _link = TextEditingController();
  final _token = TextEditingController();

  /// The token kept from a previous import; null until read, or when none.
  String? _savedToken;
  bool _editToken = false;
  bool _busy = false;
  String? _linkError;
  String? _tokenError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await ref.read(telegramStickerImporterProvider).savedToken();
    if (!mounted) return;
    setState(() {
      _savedToken = token;
      _editToken = token == null;
    });
  }

  @override
  void dispose() {
    _link.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final l = AppL10n.of(context);
    final token = _editToken ? _token.text.trim() : _savedToken;
    final badLink = const ParseStickerPackLink()(_link.text) == null;
    final noToken = token == null || token.isEmpty;
    setState(() {
      _linkError = badLink ? l.stickerImportBadLink : null;
      _tokenError = noToken ? l.formRequired : null;
      _error = null;
    });
    if (badLink || noToken) return;
    setState(() => _busy = true);
    final result = await ref
        .read(stickerImportsProvider.notifier)
        .start(_link.text, token: token);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        setState(() {
          _busy = false;
          if (failure is AuthFailure) {
            _editToken = true;
            _tokenError = l.stickerImportBadToken;
          } else {
            _error = switch (failure) {
              NotFoundFailure() => l.stickerImportNoSet,
              NetworkFailure() => l.stickerImportNetwork,
              ValidationFailure() => l.stickerImportBadLink,
              _ => l.stickerImportFailed,
            };
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final error = _error;
    return AppDialogFrame(
      title: l.stickerImportTitle,
      leadingIcon: LucideIcons.packagePlus300,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _busy,
          onPressed: _busy ? null : _import,
          child: Text(l.stickerImportAction),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConnectionTextField(
              label: l.stickerImportLink,
              controller: _link,
              hint: l.stickerImportLinkHint,
              autofocus: true,
              prefixIcon: LucideIcons.link2300,
              errorText: _linkError,
              onSubmitted: (_) => _busy ? null : _import(),
            ),
            SizedBox(height: s.xl),
            if (_editToken) ...[
              ConnectionTextField(
                label: l.stickerImportToken,
                controller: _token,
                obscure: true,
                prefixIcon: LucideIcons.keyRound300,
                errorText: _tokenError,
                onSubmitted: (_) => _busy ? null : _import(),
              ),
              SizedBox(height: s.sm),
              Text(
                l.stickerImportTokenHelp,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ] else if (_savedToken != null)
              Row(
                children: [
                  Icon(
                    LucideIcons.keyRound300,
                    size: context.sizes.iconSm,
                    color: c.textTertiary,
                  ),
                  SizedBox(width: s.sm),
                  Expanded(
                    child: Text(
                      l.stickerImportTokenSaved,
                      style: context.typography.bodySm.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  AppButton.text(
                    size: AppButtonSize.small,
                    onPressed: _busy
                        ? null
                        : () => setState(() => _editToken = true),
                    child: Text(l.stickerImportChangeToken),
                  ),
                ],
              ),
            if (_busy) ...[
              SizedBox(height: s.xl),
              const LinearProgressIndicator(),
              SizedBox(height: s.sm),
              Text(
                l.stickerImportChecking,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
            if (error != null) ...[
              SizedBox(height: s.lg),
              Text(
                error,
                style: context.typography.bodySm.copyWith(color: c.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
