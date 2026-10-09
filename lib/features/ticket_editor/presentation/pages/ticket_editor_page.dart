import 'package:flutter/material.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/bug_editor_view.dart';
import '../widgets/task_editor_view.dart';

/// The full-screen page that adds or edits a ZenTao bug or task.
class TicketEditorPage extends StatelessWidget {
  const TicketEditorPage({super.key, required this.route});

  final TicketEditorRoute route;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.background,
    child: switch (route) {
      NewBugRoute() ||
      EditBugRoute() => BugEditorView(key: ValueKey(route), route: route),
      NewTaskRoute() ||
      EditTaskRoute() => TaskEditorView(key: ValueKey(route), route: route),
    },
  );
}
