import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// A header icon button that copies [url] to the clipboard, briefly showing
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
    return AppIconButton(
      icon: _copied ? LucideIcons.check300 : LucideIcons.link300,
      tooltip: _copied ? l.linkCopied : l.copyLink,
      onPressed: _copy,
    );
  }
}
