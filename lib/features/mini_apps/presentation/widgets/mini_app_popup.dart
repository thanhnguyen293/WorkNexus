import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';

/// The window a page asked for (`window.open`, a `target="_blank"` link, a
/// sign-in pop-up) shown over the mini app, inside the app. It is the page's
/// own window, so the page can talk back to its opener and close it — what a
/// pop-up sign-in needs to finish.
class MiniAppPopup extends StatefulWidget {
  const MiniAppPopup({super.key, required this.windowId});

  final int windowId;

  /// Shows the pop-up for [windowId]; resolves when it closes.
  static Future<void> show(BuildContext context, int windowId) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MiniAppPopup(windowId: windowId),
      );

  @override
  State<MiniAppPopup> createState() => _MiniAppPopupState();
}

class _MiniAppPopupState extends State<MiniAppPopup> {
  String _title = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(s.xl5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width.clamp(0, 520),
        height: size.height.clamp(0, 720),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl3, s.xs, s.xs, s.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: LucideIcons.x300,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: InAppWebView(
                windowId: widget.windowId,
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  isInspectable: kDebugMode,
                ),
                onTitleChanged: (_, title) =>
                    setState(() => _title = title ?? ''),
                // The page closes its own window when it is done (sign-in).
                onCloseWindow: (_) {
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
