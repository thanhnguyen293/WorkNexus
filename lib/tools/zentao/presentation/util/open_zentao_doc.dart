import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../providers/zentao_doc_providers.dart';

/// Opens document [docId] of library [libId] in the reader: the library
/// becomes the location's scope and the document the one open in it.
void openZenTaoDoc(WidgetRef ref, String libId, String docId) {
  ref.read(appNavProvider.notifier).selectScope(libId);
  ref.read(zentaoOpenDocProvider.notifier).open(libId, docId);
}
