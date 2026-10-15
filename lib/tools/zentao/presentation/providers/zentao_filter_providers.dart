import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../features/connections/presentation/providers/zentao_profile_providers.dart';
import 'zentao_board_providers.dart';

/// Detected regional zone (e.g. 'VN') derived from user profile's department or realname.
final userZoneProvider = Provider<String>((ref) {
  final lookups = ref.watch(lookupsProvider);
  for (final account in lookups.accounts.values) {
    if (account.providerType.name.toLowerCase() == 'zentao') {
      final profile = ref
          .watch(zenTaoProfileProvider(account.id))
          .asData
          ?.value;
      if (profile != null) {
        if (profile.department != null && profile.department!.isNotEmpty) {
          final parts = profile.department!.split('>');
          final first = parts.first.trim();
          if (first.isNotEmpty) return first;
        }
        final match = RegExp(r'_([A-Z]{2})_').firstMatch(profile.realname);
        if (match != null) return match.group(1)!;
        if (profile.realname.contains('VN')) return 'VN';
      }
    }
  }
  return 'VN';
});

/// Currently active zone filter string ('VN' by default, null for 'All Zones').
final activeZoneFilterProvider =
    NotifierProvider<ActiveZoneFilterController, String?>(
      ActiveZoneFilterController.new,
    );

class ActiveZoneFilterController extends Notifier<String?> {
  @override
  String? build() => ref.watch(userZoneProvider);

  void setZone(String? zone) => state = zone;
  void toggleAll() =>
      state = (state == null) ? ref.read(userZoneProvider) : null;
}

/// Currently selected functional module tag filter (e.g. 'Backend', 'Mobile', null for All).
final selectedModuleProvider =
    NotifierProvider<SelectedModuleController, String?>(
      SelectedModuleController.new,
    );

class SelectedModuleController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? module) => state = module;
}

class ModuleTally {
  const ModuleTally({
    required this.name,
    required this.count,
    this.submodules = const [],
  });

  final String name;
  final int count;
  final List<ModuleTally> submodules;
}

/// Discovers functional modules from current board tickets (e.g. [Backend], [Mobile]).
final availableModulesProvider = Provider<List<ModuleTally>>((ref) {
  final section = ref.watch(
    appNavProvider.select((s) => s.currentLocation?.section.value),
  );
  final List<Ticket> tickets;
  if (section == 'zentao.tasks') {
    tickets = ref
        .watch(zentaoTaskBoardProvider)
        .columns
        .expand((c) => c.tickets)
        .toList();
  } else if (section == 'zentao.bugs') {
    tickets = ref
        .watch(zentaoBugBoardProvider)
        .columns
        .expand((c) => c.tickets)
        .toList();
  } else {
    tickets = const [];
  }

  final counts = <String, int>{};
  final regex = RegExp(r'\[([^\]]+)\]');

  for (final t in tickets) {
    final matches = regex.allMatches(t.title);
    for (final m in matches) {
      final tag = m.group(1)?.trim();
      if (tag != null && tag.isNotEmpty && tag != 'Task' && tag != 'Bug') {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    for (final label in t.labels) {
      if (label.startsWith('module:')) {
        final mod = label.substring(7).trim();
        if (mod.isNotEmpty) {
          counts[mod] = (counts[mod] ?? 0) + 1;
        }
      }
    }
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [for (final e in sorted) ModuleTally(name: e.key, count: e.value)];
});
