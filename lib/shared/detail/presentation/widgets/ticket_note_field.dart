import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/rich_text_editor.dart';
import '../../../../l10n/app_localizations.dart';
import 'action_dialog_scaffold.dart';

/// The note an action dialog sends with its action. ZenTao takes it as HTML
/// (its own forms use a rich editor), so it is rich there; plain elsewhere.
class TicketNoteController {
  TicketNoteController(Ticket ticket)
    : rich = ticket.providerType == ProviderType.zentao;

  final bool rich;
  final html = HtmlEditingController();
  final text = TextEditingController();

  /// What to send: HTML when [rich], else the text.
  String get value => rich ? html.html : text.text;

  void dispose() {
    html.dispose();
    text.dispose();
  }
}

/// An action dialog's note field: a rich editor whose pasted, dropped or
/// picked images are uploaded to the ticket's ZenTao, or a plain text field.
class TicketNoteField extends ConsumerStatefulWidget {
  const TicketNoteField({
    super.key,
    required this.ticket,
    required this.controller,
  });

  final Ticket ticket;
  final TicketNoteController controller;

  @override
  ConsumerState<TicketNoteField> createState() => _TicketNoteFieldState();
}

class _TicketNoteFieldState extends ConsumerState<TicketNoteField> {
  // ZenTao files uploads under a form id; one per field is enough.
  final _uid = DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  Future<String?> _uploadImage(Uint8List bytes, String name) async {
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .uploadImage(widget.ticket.accountId, _uid, bytes, name);
    return res is Ok<String> ? res.value : null;
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.controller;
    if (!note.rich) return NoteField(note.text);
    return RichTextEditor(
      controller: note.html,
      minHeight: 96,
      placeholder: AppL10n.of(context).taskDetailNoteHint,
      imageLoader: (url) =>
          getIt<TicketDetailService>().fetchTicketImage(widget.ticket, url),
      onUploadImage: _uploadImage,
    );
  }
}
