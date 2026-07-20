import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Panel-level (non-state-changing) actions in a two-pane detail header: refresh,
/// copy link, open in browser, edit (on the provider's web page), and close the
/// panel. Shared by the GitLab MR and GitHub PR headers. State transitions live
/// in the gated merge panel + composer, so they aren't duplicated here.
class DetailPanelHeaderActions extends StatelessWidget {
  const DetailPanelHeaderActions({
    super.key,
    required this.ticket,
    required this.onSync,
    required this.onClosePanel,
  });

  final Ticket ticket;
  final VoidCallback onSync;
  final VoidCallback onClosePanel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final url = ticket.url;
    final hasUrl = url != null && url.isNotEmpty;
    return Wrap(
      spacing: context.spacing.sm,
      runSpacing: context.spacing.sm,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _HeaderIconButton(icon: Icons.sync, tooltip: l.refresh, onTap: onSync),
        if (hasUrl) _CopyLinkButton(url: url),
        if (hasUrl)
          _HeaderIconButton(
            icon: Icons.open_in_new,
            tooltip: l.openInBrowser,
            onTap: () => openExternally(url),
          ),
        if (hasUrl)
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: () => openExternally('$url/edit'),
            child: Text(l.edit),
          ),
        _HeaderIconButton(
          icon: Icons.close,
          tooltip: l.close,
          onTap: onClosePanel,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = context.spacing.xl5 + context.spacing.xs;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(icon, size: context.spacing.xl4, color: c.textSecondary),
        ),
      ),
    );
  }
}

class _CopyLinkButton extends StatefulWidget {
  const _CopyLinkButton({required this.url});

  final String url;

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return _HeaderIconButton(
      icon: _copied ? Icons.check : Icons.link,
      tooltip: _copied ? l.linkCopied : l.copyLink,
      onTap: _copy,
    );
  }
}
