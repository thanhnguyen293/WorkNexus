import 'package:flutter/widgets.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/debug/app_talker.dart';
import '../../domain/usecases/find_whats_new.dart';
import 'whats_new_dialog.dart';

/// Wraps the app shell and, on the first launch after an update, shows what
/// every release since the last version run brought.
class WhatsNewAtLaunch extends StatefulWidget {
  const WhatsNewAtLaunch({super.key, required this.child});

  final Widget child;

  @override
  State<WhatsNewAtLaunch> createState() => _WhatsNewAtLaunchState();
}

class _WhatsNewAtLaunchState extends State<WhatsNewAtLaunch> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final result = await getIt<FindWhatsNew>()();
    // Nothing for the user to act on: a failed look is only logged, and
    // tried again next launch.
    if (result.failureOrNull case final failure?) {
      appTalker.warning("What's new: ${failure.message}");
      return;
    }
    final news = result.valueOrNull;
    if (news == null || !mounted) return;
    await WhatsNewDialog.show(context, news);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
