import 'package:flutter/material.dart';

import '../../../core/domain/value_objects/provider_type.dart';
import 'add_connection_dialog.dart';
import 'github_connection_dialog.dart';
import 'gitlab_connection_dialog.dart';

/// "Connect account": one dialog with the provider picker on top and the
/// picked provider's form under it. Switching provider starts that form
/// afresh.
class ConnectAccountDialog extends StatefulWidget {
  const ConnectAccountDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => const ConnectAccountDialog(),
  );

  @override
  State<ConnectAccountDialog> createState() => _ConnectAccountDialogState();
}

class _ConnectAccountDialogState extends State<ConnectAccountDialog> {
  ProviderType _provider = ProviderType.zentao;

  void _pick(ProviderType provider) => setState(() => _provider = provider);

  @override
  Widget build(BuildContext context) => switch (_provider) {
    ProviderType.github => GitHubConnectionDialog(onProviderChanged: _pick),
    ProviderType.gitlab => GitLabConnectionDialog(onProviderChanged: _pick),
    // Jira cannot be picked yet (see ConnectionProviderPicker).
    ProviderType.zentao ||
    ProviderType.jira => AddConnectionDialog(onProviderChanged: _pick),
  };
}
