import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../l10n/app_localizations.dart';

/// The shared detail-panel header icon button — a 26×26 subtle-filled, bordered
/// square with a tooltip. Used by both the standard ZenTao/issue panel header and
/// the GitLab MR / GitHub PR two-pane headers so every header reads as one style.
class DetailHeaderIconButton extends StatelessWidget {
  const DetailHeaderIconButton({
    super.key,
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.sm),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 15, color: c.textSecondary),
        ),
      ),
    );
  }
}

/// A [DetailHeaderIconButton] that copies [url] to the clipboard, briefly showing
/// a check mark + "Copied!" tooltip as confirmation.
class DetailHeaderCopyLinkButton extends StatefulWidget {
  const DetailHeaderCopyLinkButton({super.key, required this.url});

  final String url;

  @override
  State<DetailHeaderCopyLinkButton> createState() =>
      _DetailHeaderCopyLinkButtonState();
}

class _DetailHeaderCopyLinkButtonState
    extends State<DetailHeaderCopyLinkButton> {
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
    return DetailHeaderIconButton(
      icon: _copied ? Icons.check : Icons.link,
      tooltip: _copied ? l.linkCopied : l.copyLink,
      onTap: _copy,
    );
  }
}
