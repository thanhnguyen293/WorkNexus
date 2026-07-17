import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// App-shell view state shared across features: which ticket's detail overlay is
/// open, and whether the settings view replaces the board. Lives in the shared
/// kernel so features coordinate through it (rule 10.2) instead of importing one
/// another's presentation layer.

/// The currently open ticket in the detail slide-over (null = closed).
class OpenTicketController extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String id) => state = id;
  void close() => state = null;
}

final openTicketIdProvider = NotifierProvider<OpenTicketController, String?>(
  OpenTicketController.new,
);

/// Whether the Settings / Integrations view is showing (replaces the board).
final settingsOpenProvider = StateProvider<bool>((ref) => false);
