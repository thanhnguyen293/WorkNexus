import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/person_directory.dart';

/// The tracker-backed people lookup, wired in by the app (`main.dart`) so chat
/// can show a colleague's department and contacts without importing ZenTao.
/// Null (tests, no tracker) means chat shows only what it knows itself.
final personDirectoryProvider = Provider<PersonDirectory?>((ref) => null);
