import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/util/dropped_files.dart';
import 'chat_providers.dart';

/// Files dropped on a composer, held in its input until sent or removed.
/// While any are held the input takes no text.
final chatStagedFilesProvider =
    StateProvider.family<List<DroppedFile>, ChatComposerKey>(
      (ref, key) => const [],
    );
