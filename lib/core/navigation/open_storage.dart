import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the "Storage & cache" dialog.
typedef OpenStorage = void Function(BuildContext context);

/// The app's one storage dialog (chat files plus the synced local data),
/// wired in by the app because it spans features; any feature opens it from
/// here. Null (tests) means there is nothing to open.
final openStorageProvider = Provider<OpenStorage?>((ref) => null);
