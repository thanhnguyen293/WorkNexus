import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/zentao_doc_providers.dart';
import '../widgets/zentao_doc_viewer.dart';

/// The L5 Viewport section for ZenTao Docs: the open document, across the
/// whole viewport. Libraries and their documents are picked in the nav
/// pane's tree; the open document is kept per account, so it is still open
/// after a trip to Tasks or Bugs.
class ZentaoDocsSection extends ConsumerWidget {
  const ZentaoDocsSection({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docId = ref.watch(
      zentaoOpenDocProvider.select((m) => m[account.id]?.docId),
    );
    if (docId == null) {
      return AppStateView.empty(
        title: AppL10n.of(context).docsPickDocument,
        icon: LucideIcons.fileText300,
      );
    }
    return ZenTaoDocViewer(
      key: ValueKey(docId),
      account: account,
      docId: docId,
    );
  }
}
