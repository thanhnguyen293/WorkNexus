import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/privacy_mask.dart';
import '../../domain/value_objects/chat_privacy_part.dart';
import '../providers/chat_privacy_providers.dart';

/// Shows [mask] in place of [child] while the privacy mode hides [part];
/// pointing at it (or at the [PrivacyRevealRegion] around it) shows [child].
class ChatPrivacyMask extends ConsumerWidget {
  const ChatPrivacyMask({
    super.key,
    required this.part,
    required this.mask,
    required this.child,
  });

  final ChatPrivacyPart part;
  final Widget mask;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyMask(
    masked: ref.watch(chatPrivacyHiddenProvider(part)),
    mask: mask,
    child: child,
  );
}

/// One line of [text] as the privacy mode shows it: the real text, or dots
/// while it hides [part] (never, when null). Pointing at it shows the text.
class ChatPrivacyText extends StatelessWidget {
  const ChatPrivacyText(this.text, {super.key, required this.part, this.style});

  final String text;
  final ChatPrivacyPart? part;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final real = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final part = this.part;
    if (part == null) return real;
    return ChatPrivacyMask(
      part: part,
      mask: Text(kPrivacyMaskText, maxLines: 1, style: style),
      child: real,
    );
  }
}

/// Fades [child] almost out while the privacy mode hides [part] (messages,
/// unless told otherwise); pointing at it, or at the [PrivacyRevealRegion]
/// around it, shows it. For content on a solid background — a bubble's
/// insides, a card's body.
class ChatPrivacyFade extends ConsumerWidget {
  const ChatPrivacyFade({
    super.key,
    this.part = ChatPrivacyPart.message,
    required this.child,
  });

  final ChatPrivacyPart part;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyFade(
    faded: ref.watch(chatPrivacyHiddenProvider(part)),
    child: child,
  );
}

/// The grey a hidden picture shows as. Opaque — the skeleton tints alone are
/// see-through — and a step off the surface, so the box still reads.
Color chatPrivacyCoverColor(BuildContext context) => Color.alphaBlend(
  context.colors.skeletonHighlight,
  context.colors.surfaceSubtle,
);

/// Covers a picture (an image, a video, a sticker) with a plain grey box
/// while the privacy mode hides messages; pointing at it, or at the
/// [PrivacyRevealRegion] around it, shows it.
class ChatPrivacyCover extends ConsumerWidget {
  const ChatPrivacyCover({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyCover(
    covered: ref.watch(chatPrivacyHiddenProvider(ChatPrivacyPart.message)),
    color: chatPrivacyCoverColor(context),
    borderRadius: BorderRadius.circular(context.radii.md),
    child: child,
  );
}
