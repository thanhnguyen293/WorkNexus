import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// Shows a context menu with copy actions (Title, ID, Markdown link, Link)
/// for a task or bug row.
Future<void> showZenTaoRowContextMenu(
  BuildContext context,
  Offset at,
  Ticket ticket,
) async {
  final l = AppL10n.of(context);
  final url = ticket.url ?? '';
  final hasUrl = url.isNotEmpty;

  final entries = [
    AppMenuEntry(icon: LucideIcons.copy300, label: l.copyTitle),
    AppMenuEntry(
      icon: LucideIcons.hash300,
      label: '${l.copyId} (#${ticket.externalKey})',
    ),
    AppMenuEntry(icon: LucideIcons.fileCode300, label: l.copyMarkdownLink),
    if (hasUrl) AppMenuEntry(icon: LucideIcons.link300, label: l.copyLink),
  ];

  final picked = await showAppContextMenu(context, at: at, entries: entries);
  if (picked == null || !context.mounted) return;

  switch (picked) {
    case 0:
      await Clipboard.setData(ClipboardData(text: ticket.title));
      if (context.mounted) showAppSnack(context, l.titleCopied);
    case 1:
      await Clipboard.setData(ClipboardData(text: '#${ticket.externalKey}'));
      if (context.mounted) showAppSnack(context, l.idCopied);
    case 2:
      final md = hasUrl
          ? '[#${ticket.externalKey} ${ticket.title}]($url)'
          : '[#${ticket.externalKey}] ${ticket.title}';
      await Clipboard.setData(ClipboardData(text: md));
      if (context.mounted) showAppSnack(context, l.markdownLinkCopied);
    case 3:
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) showAppSnack(context, l.linkCopied);
  }
}

/// A compact, quick copy button revealed when hovering over a task or bug row.
class ZenTaoRowQuickCopyButton extends StatefulWidget {
  const ZenTaoRowQuickCopyButton({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<ZenTaoRowQuickCopyButton> createState() =>
      _ZenTaoRowQuickCopyButtonState();
}

class _ZenTaoRowQuickCopyButtonState extends State<ZenTaoRowQuickCopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final l = AppL10n.of(context);
    await Clipboard.setData(ClipboardData(text: widget.ticket.title));
    if (!mounted) return;
    setState(() => _copied = true);
    showAppSnack(context, l.titleCopied);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);

    return Tooltip(
      message: _copied ? l.titleCopied : l.copyTitle,
      child: HoverSurface(
        onTap: _copy,
        borderRadius: BorderRadius.circular(context.radii.xs),
        color: _copied ? c.mixT(c.success, 0.15) : c.mixT(c.textTertiary, 0.08),
        hoverColor: c.mixT(c.accent, 0.15),
        padding: const EdgeInsets.all(3),
        child: Icon(
          _copied ? LucideIcons.check300 : LucideIcons.copy300,
          size: 13,
          color: _copied ? c.success : c.textSecondary,
        ),
      ),
    );
  }
}
