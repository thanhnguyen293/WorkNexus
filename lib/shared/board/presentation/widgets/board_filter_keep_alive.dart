import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/filter_providers.dart';

/// Keeps the board filter subscribed from a part of the shell that never goes
/// offstage.
///
/// The filter follows the board the user navigates to (`FilterController`
/// listens to `boardKeyProvider`). If only the boards themselves watched it,
/// Riverpod would pause it whenever the viewport puts them offstage, then
/// catch up on the navigation mid-build when one comes back, and switching
/// the filter there is a provider write during build, which Riverpod refuses.
class BoardFilterKeepAlive extends ConsumerWidget {
  const BoardFilterKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(filterStateProvider, (_, _) {});
    return child;
  }
}
