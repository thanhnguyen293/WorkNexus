import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/privacy_blur.dart';
import '../../domain/value_objects/chat_privacy_part.dart';
import '../providers/chat_privacy_providers.dart';

/// Blurs [child] while the privacy mode hides [part]; hovering or focusing
/// it (or the [PrivacyRevealRegion] around it) shows it again.
class ChatPrivacyBlur extends ConsumerWidget {
  const ChatPrivacyBlur({super.key, required this.part, required this.child});

  final ChatPrivacyPart part;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyBlur(
    blurred: ref.watch(chatPrivacyBlurProvider(part)),
    child: child,
  );
}
