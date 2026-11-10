import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../providers/zentao_doc_providers.dart';

/// Opens document [docId] of library [libId] in [accountId]'s reader. The
/// library also becomes the location's scope (the breadcrumb shows it), but
/// the reader follows [zentaoOpenDocProvider], which outlives a scope reset.
void openZenTaoDoc(
  WidgetRef ref,
  String accountId,
  String libId,
  String docId,
) {
  ref.read(appNavProvider.notifier).selectScope(libId);
  ref.read(zentaoOpenDocProvider.notifier).open(accountId, libId, docId);
}
