import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import 'attachment_kinds.dart';
import 'attachment_video_view.dart';
import 'attachment_viewer_header.dart';

/// Opens the in-app attachment viewer for [att] as a modal dialog.
Future<void> showAttachmentViewer(
  BuildContext context,
  Ticket ticket,
  TicketAttachment att,
) => showDialog<void>(
  context: context,
  builder: (_) => AttachmentViewerDialog(ticket: ticket, attachment: att),
);

/// A modal that previews a ticket attachment (image or video) directly in the
/// app, with a button to save it to Downloads. The file is fetched once through
/// the account's authenticated client into a temp cache.
class AttachmentViewerDialog extends ConsumerStatefulWidget {
  const AttachmentViewerDialog({
    super.key,
    required this.ticket,
    required this.attachment,
  });

  final Ticket ticket;
  final TicketAttachment attachment;

  @override
  ConsumerState<AttachmentViewerDialog> createState() =>
      _AttachmentViewerDialogState();
}

class _AttachmentViewerDialogState
    extends ConsumerState<AttachmentViewerDialog> {
  Future<String?>? _pathFuture;
  String? _path;
  bool _loading = true;
  bool _saving = false;

  /// The window went full screen for the video: the viewer fills it.
  bool _expanded = false;
  final _window = const DesktopWindowService();

  Future<void> _toggleExpanded() async {
    setState(() => _expanded = !_expanded);
    await _window.toggleFullScreen();
  }

  @override
  void dispose() {
    // Closing the viewer leaves full screen too.
    if (_expanded) _window.exitFullScreen();
    super.dispose();
  }

  bool get _isVideo =>
      kVideoExts.contains(widget.attachment.extension?.toLowerCase() ?? '');

  @override
  void initState() {
    super.initState();
    // A video streams, so it is only downloaded whole to save it (or when
    // streaming fails); anything else is shown from the downloaded file.
    if (!_isVideo) _download();
  }

  /// The one download of the file, shared by the preview and Save.
  Future<String?> _download() => _pathFuture ??= _load();

  Future<String?> _load() async {
    final path = await getIt<TicketDetailService>().cacheAttachment(
      widget.ticket,
      widget.attachment,
    );
    if (mounted) {
      setState(() {
        _path = path;
        _loading = false;
      });
    }
    return path;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    // Download is always enabled; if the preview is still caching, await that
    // same fetch rather than starting a second one.
    final path = _path ?? await _download();
    final saved = path == null
        ? null
        : await getIt<TicketDetailService>().saveAttachmentToDownloads(
            path,
            widget.attachment.title,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    final l = AppL10n.of(context);
    showAppSnack(
      context,
      saved != null ? l.savedToDownloads : l.saveFailed,
      isError: saved == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: c.card,
      insetPadding: _expanded ? EdgeInsets.zero : null,
      shape: RoundedRectangleBorder(
        borderRadius: _expanded
            ? BorderRadius.zero
            : BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: _expanded
            ? BoxConstraints.tight(size)
            : BoxConstraints(
                maxWidth: (size.width * 0.8).clamp(360.0, 960.0),
                maxHeight: (size.height * 0.85).clamp(320.0, 720.0),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AttachmentViewerHeader(
              attachment: widget.attachment,
              saving: _saving,
              onSave: _save,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: _isVideo
                  ? AttachmentVideoView(
                      stream: () => getIt<TicketDetailService>()
                          .attachmentStream(widget.ticket, widget.attachment),
                      download: _download,
                      expanded: _expanded,
                      onToggleExpand: _toggleExpanded,
                      sizeBytes: widget.attachment.size,
                    )
                  : _ViewerBody(
                      loading: _loading,
                      path: _path,
                      attachment: widget.attachment,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the viewer shows under its header for a file that isn't a video: a
/// spinner while it caches, then the image, or why there is nothing to
/// preview.
class _ViewerBody extends StatelessWidget {
  const _ViewerBody({
    required this.loading,
    required this.path,
    required this.attachment,
  });

  final bool loading;
  final String? path;
  final TicketAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (loading) return const AppStateView.loading();
    final path = this.path;
    if (path == null) {
      return AppStateView.error(title: l.attachmentLoadFailed);
    }
    final ext = attachment.extension?.toLowerCase() ?? '';
    if (kImageExts.contains(ext)) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(path))),
      );
    }
    return AppStateView.empty(
      icon: LucideIcons.file300,
      title: l.previewUnavailable,
    );
  }
}
