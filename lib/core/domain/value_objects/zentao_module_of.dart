import '../entities/provider_entity.dart';
import '../entities/ticket.dart';

/// The ZenTao module (id) a bug or task sits in; null for any other ticket or
/// one without a module ('0' is ZenTao's "no module", kept as given).
String? zentaoModuleOf(Ticket ticket) => switch (ticket.providerEntity) {
  ZenTaoBugEntity(:final module) => module,
  ZenTaoTaskEntity(:final module) => module,
  _ => null,
};
