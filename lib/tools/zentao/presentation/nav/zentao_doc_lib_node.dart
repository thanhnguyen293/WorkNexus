import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/entities/zentao_doc_summary.dart';
import '../../domain/usecases/toggle_zentao_doc_pin.dart';
import '../providers/zentao_doc_providers.dart';
import '../util/open_zentao_doc.dart';
import 'zentao_doc_tree_row.dart';

/// A library in the Docs tree; opened, its documents below it, fetched the
/// first time it opens.
class ZenTaoDocLibNode extends ConsumerWidget {
  const ZenTaoDocLibNode({
    super.key,
    required this.account,
    required this.location,
    required this.lib,
    required this.pins,
  });

  final Account account;
  final ToolLocation location;
  final ZenTaoDocLib lib;
  final ZenTaoDocPins pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      zentaoDocExpandedLibsProvider.select(
        (set) => set.contains(ZenTaoDocExpandedLibs.keyOf(account.id, lib.id)),
      ),
    );
    final pinned = pins.hasLib(lib.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZenTaoDocTreeRow(
          icon: LucideIcons.libraryBig300,
          label: lib.name,
          expanded: expanded,
          onTap: () => ref
              .read(zentaoDocExpandedLibsProvider.notifier)
              .toggle(account.id, lib.id),
          pinned: pinned,
          pinTooltip: pinned ? l.docsUnpinLibrary : l.docsPinLibrary,
          onPin: () => getIt<ToggleZenTaoDocPin>()(account.id, lib: lib),
        ),
        if (expanded)
          _LibDocs(account: account, location: location, lib: lib, pins: pins),
      ],
    );
  }
}

class _LibDocs extends ConsumerWidget {
  const _LibDocs({
    required this.account,
    required this.location,
    required this.lib,
    required this.pins,
  });

  final Account account;
  final ToolLocation location;
  final ZenTaoDocLib lib;
  final ZenTaoDocPins pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final syncKey = (account: account, libId: lib.id, docId: null);
    final sync = ref.watch(zentaoDocSyncProvider(syncKey));
    final docs =
        ref
            .watch(zentaoDocsProvider((accountId: account.id, libId: lib.id)))
            .asData
            ?.value ??
        const <ZenTaoDocSummary>[];
    final open = ref.watch(zentaoOpenDocProvider.select((m) => m[account.id]));
    final openId = open?.libId == lib.id ? open?.docId : null;

    if (docs.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          left: context.sizes.iconSm + context.spacing.xs,
        ),
        child: SidebarStatusRow(
          label: sync.isLoading
              ? l.docsLoadingDocs
              : sync.hasError
              ? l.docsLibrariesUnavailable
              : l.docsEmptyLibrary,
          loading: sync.isLoading,
          isError: sync.hasError,
          onRetry: sync.hasError
              ? () =>
                    ref.read(zentaoDocSyncProvider(syncKey).notifier).refresh()
              : null,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final doc in docs)
          ZenTaoDocRow(
            account: account,
            doc: doc,
            pins: pins,
            selected: doc.id == openId,
          ),
      ],
    );
  }
}

/// A document in the tree, under its library or (with [libraryName]) in the
/// pinned group.
class ZenTaoDocRow extends ConsumerWidget {
  const ZenTaoDocRow({
    super.key,
    required this.account,
    required this.doc,
    required this.pins,
    required this.selected,
    this.libraryName,
  });

  final Account account;
  final ZenTaoDocSummary doc;
  final ZenTaoDocPins pins;
  final bool selected;
  final String? libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final pinned = pins.hasDoc(doc.id);
    return ZenTaoDocTreeRow(
      icon: doc.acl == null || doc.acl == 'open'
          ? LucideIcons.fileText300
          : LucideIcons.fileLock300,
      label: doc.title,
      subtitle: libraryName,
      indented: libraryName == null,
      selected: selected,
      onTap: () => openZenTaoDoc(ref, account.id, doc.libId, doc.id),
      pinned: pinned,
      pinTooltip: pinned ? l.docsUnpinDoc : l.docsPinDoc,
      onPin: () => getIt<ToggleZenTaoDocPin>()(account.id, doc: doc),
    );
  }
}
