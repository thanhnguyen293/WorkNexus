import 'package:flutter/widgets.dart';

import '../domain/value_objects/priority.dart';
import '../domain/value_objects/provider_type.dart';
import '../domain/value_objects/unified_status.dart';
import 'app_colors.dart';
import 'app_radii.dart';

/// Brand colors per provider (from the design's PROV map). Kept in the theme
/// layer so the domain enum stays Flutter-free.
Color providerBrandColor(ProviderType p) => switch (p) {
  ProviderType.github => const Color(0xFF6E7681),
  ProviderType.gitlab => const Color(0xFFFC6D26),
  ProviderType.jira => const Color(0xFF4C9AFF),
  ProviderType.zentao => const Color(0xFF3FA66B),
};

/// Status → dot color token (design STAT dot mapping).
Color statusColor(AppColors c, UnifiedStatus s) => switch (s) {
  UnifiedStatus.inbox => c.textTertiary,
  UnifiedStatus.todo => c.accent,
  UnifiedStatus.inprogress => c.caution,
  UnifiedStatus.review => c.info,
  UnifiedStatus.blocked => c.error,
  UnifiedStatus.done => c.success,
};

/// Priority → color token (design PRIO_VAR ordering).
Color priorityColor(AppColors c, Priority p) => switch (p) {
  Priority.urgent => c.error,
  Priority.high => c.caution,
  Priority.medium => c.notice,
  Priority.low => c.textTertiary,
};

/// ZenTao severity (1 = most severe … 4 = least) → color token. Unknown → null.
Color? severityColor(AppColors c, int? severity) => switch (severity) {
  1 => c.error,
  2 => c.caution,
  3 => c.notice,
  4 => c.textTertiary,
  _ => null,
};

/// Provider-specific priority label (design prioTextFor).
String priorityLabel(ProviderType prov, Priority p) {
  final lv = p.level;
  return switch (prov) {
    ProviderType.github => 'P$lv',
    ProviderType.gitlab => 'priority::${lv + 1}',
    ProviderType.jira => '◆ ${const ['Highest', 'High', 'Medium', 'Low'][lv]}',
    ProviderType.zentao => 'Pri ${lv + 1}',
  };
}

/// Priority-tag corner radius varies by provider (design prioStyleFor).
double priorityRadius(AppRadii r, ProviderType prov) => switch (prov) {
  ProviderType.jira => r.pill,
  ProviderType.zentao => r.xs,
  _ => r.xs,
};

/// A ticket's display reference (design idText/refShort).
String ticketRef(ProviderType prov, String key, String? type) => switch (prov) {
  ProviderType.jira => key,
  ProviderType.zentao => '${type ?? ''} #$key',
  _ => '#$key',
};
