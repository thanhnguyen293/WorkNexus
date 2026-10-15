import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/mini_app_links.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../core/platform/link_router.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_providers.dart';
import '../util/mini_app_notifications.dart';
import 'mini_app_view.dart';

/// Holds every mini app opened this session, showing only the current one.
/// The others stay mounted (hidden) so switching on the rail does not reload
/// a page or sign the user out; a removed app is dropped.
///
/// Also the bridge to the rest of the app: it brings a mini app forward when
/// its notification is tapped, and for links it tells the rest of the app which sites have a
/// mini app, and takes over a tapped link to one of them instead of the
/// browser.
class MiniAppsHost extends ConsumerStatefulWidget {
  const MiniAppsHost({super.key, required this.visible});

  /// Whether the mini app view is the one on screen.
  final bool visible;

  @override
  ConsumerState<MiniAppsHost> createState() => _MiniAppsHostState();
}

class _MiniAppsHostState extends ConsumerState<MiniAppsHost>
    implements LinkHandler {
  /// Ids opened so far, in opening order.
  final _opened = <String>[];
  int _seq = 0;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    linkRouter.register(LinkStage.miniApp, this);
    _taps = ref.read(miniAppNotifierProvider).taps.listen(_onNotificationTap);
    ref.listenManual<AsyncValue<List<MiniApp>>>(
      miniAppsProvider,
      (_, apps) => _publishTargets(apps.asData?.value ?? const []),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    linkRouter.unregister(LinkStage.miniApp, this);
    _taps?.cancel();
    super.dispose();
  }

  /// Outside the build phase: providers must not change while widgets build.
  void _publishTargets(List<MiniApp> apps) => Future.microtask(() {
    if (!mounted) return;
    ref.read(miniAppLinkTargetsProvider.notifier).state = [
      for (final app in apps)
        if (Uri.tryParse(app.url)?.host case final host? when host.isNotEmpty)
          MiniAppLinkTarget(id: app.id, host: host),
    ];
  });

  /// A tap on a notification a mini app's page showed brings its app forward.
  Future<void> _onNotificationTap(String payload) async {
    final id = miniAppIdOfNotificationPayload(payload);
    if (id == null) return;
    await const DesktopWindowService().bringToFront();
    if (!mounted) return;
    ref.read(appNavProvider.notifier).showMiniApp(id);
  }

  @override
  bool handle(String url) {
    final id = findMiniAppForLink(ref.read(miniAppLinkTargetsProvider), url);
    if (id == null) return false;
    ref.read(miniAppNavigationProvider.notifier).state = MiniAppNavigation(
      id: id,
      url: url,
      seq: ++_seq,
    );
    ref.read(appNavProvider.notifier).showMiniApp(id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(miniAppsProvider).asData?.value ?? const [];
    final current = ref.watch(openMiniAppIdProvider);
    if (current != null && !_opened.contains(current)) _opened.add(current);
    _opened.removeWhere((id) => !apps.any((a) => a.id == id));
    return Offstage(
      offstage: !widget.visible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final app in apps.where((a) => _opened.contains(a.id)))
            Offstage(
              key: ValueKey(app.id),
              offstage: app.id != current,
              child: MiniAppView(app: app),
            ),
        ],
      ),
    );
  }
}
