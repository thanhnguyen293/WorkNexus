import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';

/// Color for a ZenTao status code across bugs, tasks, stories, todos and
/// executions. Only `active` differs by kind: an open bug is a problem, an
/// active story is just in progress.
Color dashboardStatusColor(AppColors c, String? status, {bool bug = false}) =>
    switch (status) {
      'active' when bug => c.error,
      'delay' => c.error,
      'active' || 'doing' || 'reviewing' || 'changing' => c.info,
      'confirmed' || 'pause' || 'suspended' || 'postponed' => c.warning,
      'resolved' || 'done' => c.success,
      _ => c.textTertiary,
    };
