import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
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
  String? _path;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await getIt<SyncService>().cacheAttachment(
      widget.ticket,
      widget.attachment,
    );
    if (!mounted) return;
    setState(() {
      _path = path;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final path = _path;
    if (path == null || _saving) return;
    setState(() => _saving = true);
    final saved = await getIt<SyncService>().saveAttachmentToDownloads(
      path,
      widget.attachment.title,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final l = AppL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved != null ? l.savedToDownloads : l.saveFailed),
      ),
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
              canSave: _path != null,
              onSave: _save,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.xl4),
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }
    final path = _path;
    if (path == null) {
      return _Message(
        icon: Icons.error_outline,
        text: AppL10n.of(context).attachmentLoadFailed,
      );
    }
    final ext = widget.attachment.extension?.toLowerCase() ?? '';
    if (kImageExts.contains(ext)) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(path))),
      );
    }
    if (kVideoExts.contains(ext)) {
      return AttachmentVideoView(path: path);
    }
    return _Message(
      icon: Icons.insert_drive_file_outlined,
      text: AppL10n.of(context).previewUnavailable,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.all(context.spacing.xl4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: c.textTertiary),
          SizedBox(height: context.spacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
