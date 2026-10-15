import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../../domain/usecases/is_mini_app_origin.dart';
import '../providers/mini_app_providers.dart';
import '../widgets/mini_app_permission_dialog.dart';
import 'mini_app_permission_kind.dart';

/// Requests for the same app and kinds that are being asked right now, so a
/// page asking twice at once gets one dialog.
final _asking = <String, Future<MiniAppPermissionDecision>>{};

/// Whether app [app]'s page, now at [origin], may use [kinds]: the answer
/// remembered for them, or — the first time — the user's, asked in a dialog
/// and then remembered. A dismissed dialog blocks this once without
/// remembering it. A page on another site than the app's is blocked without
/// asking: it would otherwise get the app's answers, or be asked about under
/// the app's name.
Future<MiniAppPermissionDecision> askMiniAppPermission(
  BuildContext context,
  WidgetRef ref,
  MiniApp app,
  Iterable<MiniAppPermissionKind> kinds, {
  required Uri? origin,
}) {
  final sorted = {...kinds}.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  if (sorted.isEmpty || !const IsMiniAppOrigin()(app.url, origin)) {
    return Future.value(MiniAppPermissionDecision.block);
  }
  final key = '${app.id}|${sorted.map((k) => k.name).join(',')}';
  return _asking[key] ??= _ask(
    context,
    ref,
    app,
    sorted,
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
  // A page in the background asks once the user opens its app, not over
  // whatever they are looking at.
  await _untilShown(ref, app.id);
  if (!context.mounted) return MiniAppPermissionDecision.block;
  final uri = Uri.tryParse(app.url);
  final answer = await MiniAppPermissionDialog.show(
    context,
    site: uri == null || uri.host.isEmpty ? app.name : uri.host,
    kinds: kinds,
  );
  if (answer == null) return MiniAppPermissionDecision.block;
  final kept = await controller.remember(app.id, kinds, answer);
  if (kept.isErr && context.mounted) {
    showAppSnack(
      context,
      AppL10n.of(context).miniAppPermissionSaveFailed,
      isError: true,
    );
  }
  return answer;
}

/// Resolves once app [id] is the one on screen.
Future<void> _untilShown(WidgetRef ref, String id) {
  final provider = miniAppShownProvider(id);
  if (ref.read(provider)) return Future.value();
  final shown = Completer<void>();
  late final ProviderSubscription<bool> sub;
  sub = ref.listenManual<bool>(provider, (_, now) {
    if (!now || shown.isCompleted) return;
    sub.close();
    shown.complete();
  });
  return shown.future;
}

/// The answer to give the web view for [request].
Future<PermissionResponse> answerMiniAppPermission(
  BuildContext context,
  WidgetRef ref,
  MiniApp app,
  PermissionRequest request,
) async {
  final kinds = [
    for (final resource in request.resources)
      ...miniAppPermissionKindsOf(resource),
  ];
  final decision = await askMiniAppPermission(
    context,
    ref,
    app,
    kinds,
    origin: request.origin,
  );
  return PermissionResponse(
    resources: request.resources,
    action: decision == MiniAppPermissionDecision.allow
        ? PermissionResponseAction.GRANT
        : PermissionResponseAction.DENY,
  );
}
