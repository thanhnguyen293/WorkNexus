import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/usecases/filter_zentao_doc_libs.dart';
import '../providers/zentao_doc_providers.dart';
import 'zentao_doc_lib_node.dart';

/// The Docs nav pane: one tree of the account's libraries, each opening onto
/// its documents, under the pinned libraries and documents. Libraries are
/// flat (the server sends no space for them); the filter narrows them by
/// name, and the pins by name or title.
class ZentaoDocLibsScopeList extends ConsumerStatefulWidget {
  const ZentaoDocLibsScopeList({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<ZentaoDocLibsScopeList> createState() =>
      _ZentaoDocLibsScopeListState();
}

class _ZentaoDocLibsScopeListState
    extends ConsumerState<ZentaoDocLibsScopeList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final account = widget.account;
    final syncKey = (account: account, libId: null, docId: null);
    final sync = ref.watch(zentaoDocSyncProvider(syncKey));
    final libs =
        ref.watch(zentaoDocLibsProvider(account.id)).asData?.value ??
        const <ZenTaoDocLib>[];
    final pins =
        ref.watch(zentaoDocPinsProvider(account.id)).asData?.value ??
        const ZenTaoDocPins();

    if (libs.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(s.md),
        child: sync.hasError
            ? SidebarStatusRow(
                label: l.docsLibrariesUnavailable,
                isError: true,
                onRetry: () =>
                    ref.read(zentaoDocSyncProvider(syncKey).notifier).refresh(),
              )
            : SidebarStatusRow(
                label: sync.isLoading
                    ? l.docsLoadingLibraries
                    : l.docsNoLibraries,
                loading: sync.isLoading,
              ),
      );
    }

    final query = _filter.trim().toLowerCase();
    final filtered = const FilterZenTaoDocLibs()(libs, _filter);
    final pinnedLibs = const FilterZenTaoDocLibs()(pins.libs, _filter);
    final pinnedDocs = [
      for (final d in pins.docs)
        if (query.isEmpty || d.title.toLowerCase().contains(query)) d,
    ];
    final libName = {for (final lib in libs) lib.id: lib.name};
    final openLib = widget.location.scopeId;
    final openDoc = openLib == null
        ? null
        : ref.watch(zentaoOpenDocProvider.select((m) => m[openLib]));

    return Column(
      children: [
        ScopeFilterField(
          placeholder: l.docsFilterLibraries,
          onChanged: (val) => setState(() => _filter = val),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(s.sm, s.xs, s.sm, s.lg),
            children: [
              if (pinnedDocs.isNotEmpty || pinnedLibs.isNotEmpty) ...[
                ScopeGroupHeader(title: l.pinned),
                for (final doc in pinnedDocs)
                  ZenTaoDocRow(
                    key: ValueKey('pin-doc-${doc.id}'),
                    account: account,
                    doc: doc,
                    pins: pins,
                    selected: doc.id == openDoc && doc.libId == openLib,
                    libraryName: libName[doc.libId] ?? '',
                  ),
                for (final lib in pinnedLibs)
                  ZenTaoDocLibNode(
                    key: ValueKey('pin-lib-${lib.id}'),
                    account: account,
                    location: widget.location,
                    lib: lib,
                    pins: pins,
                  ),
                SizedBox(height: s.md),
              ],
              ScopeGroupHeader(title: l.docsLibrariesGroup),
              if (filtered.isEmpty)
                SidebarStatusRow(label: l.docsNoLibraries)
              else
                for (final lib in filtered)
                  if (!pins.hasLib(lib.id))
                    ZenTaoDocLibNode(
                      key: ValueKey('lib-${lib.id}'),
                      account: account,
                      location: widget.location,
                      lib: lib,
                      pins: pins,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
