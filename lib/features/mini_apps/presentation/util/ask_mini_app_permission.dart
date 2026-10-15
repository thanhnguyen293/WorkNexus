import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mini_app.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../providers/mini_app_providers.dart';
import '../widgets/mini_app_permission_dialog.dart';
import 'mini_app_permission_kind.dart';

/// Requests for the same app and kinds that are being asked right now, so a
/// page asking twice at once gets one dialog.
final _asking = <String, Future<MiniAppPermissionDecision>>{};

/// Whether app [app]'s page may use [kinds]: the answer remembered for them, or
/// — the first time — the user's, asked in a dialog and then remembered. A
/// dismissed dialog blocks this once without remembering it.
Future<MiniAppPermissionDecision> askMiniAppPermission(
  BuildContext context,
  WidgetRef ref,
  MiniApp app,
  List<MiniAppPermissionKind> kinds,
) {
  final key = '${app.id}|${kinds.map((k) => k.name).join(',')}';
  return _asking[key] ??= _ask(
    context,
    ref,
    app,
    kinds,
  ).whenComplete(() => _asking.remove(key));
}

Future<MiniAppPermissionDecision> _ask(
  BuildContext context,
  WidgetRef ref,
  MiniApp app,
  List<MiniAppPermissionKind> kinds,
) async {
  final controller = ref.read(miniAppPermissionControllerProvider.notifier);
  final saved = await controller.remembered(app.id, kinds);
  if (saved != null) return saved;
  if (!context.mounted) return MiniAppPermissionDecision.block;
  final uri = Uri.tryParse(app.url);
  final answer = await MiniAppPermissionDialog.show(
    context,
    site: uri == null || uri.host.isEmpty ? app.name : uri.host,
    kinds: kinds,
  );
  if (answer == null) return MiniAppPermissionDecision.block;
  await controller.remember(app.id, kinds, answer);
  return answer;
}

/// The answer to give the web view for [request].
Future<PermissionResponse> answerMiniAppPermission(
  BuildContext context,
  WidgetRef ref,
  MiniApp app,
  PermissionRequest request,
) async {
  final kinds = {
    for (final resource in request.resources)
      ...miniAppPermissionKindsOf(resource),
  }.toList();
  final decision = await askMiniAppPermission(context, ref, app, kinds);
  return PermissionResponse(
    resources: request.resources,
    action: decision == MiniAppPermissionDecision.allow
        ? PermissionResponseAction.GRANT
        : PermissionResponseAction.DENY,
  );
}
