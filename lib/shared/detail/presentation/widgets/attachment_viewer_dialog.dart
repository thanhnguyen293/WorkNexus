import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
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
  late final Future<String?> _pathFuture;
  String? _path;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pathFuture = _load();
  }

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
    final path = _path ?? await _pathFuture;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
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
              child: _ViewerBody(
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

/// What the viewer shows under its header: a spinner while the file caches,
/// then the image / video, or why there is nothing to preview.
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
    if (kVideoExts.contains(ext)) {
      return AttachmentVideoView(path: path);
    }
    return AppStateView.empty(
      icon: LucideIcons.file300,
      title: l.previewUnavailable,
    );
  }
}
