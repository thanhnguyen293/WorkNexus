import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_trust_preview.dart';

/// Debug builds only: opens chat as if its server's certificate still needed
/// confirming (a made-up one), to see that flow without an untrusted server;
/// a second click ends the preview. Release builds get nothing (the tooltip
/// is a developer string, not localised, for that reason).
class ChatTrustDebugButton extends ConsumerWidget {
  const ChatTrustDebugButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final s = context.spacing;
    final previewing = ref.watch(chatTrustPreviewProvider) != null;
    return Tooltip(
      message: previewing
          ? 'Debug: end the certificate check preview'
          : 'Debug: preview the chat certificate check',
      child: HoverSurface(
        onTap: () {
          final preview = ref.read(chatTrustPreviewProvider.notifier);
          if (previewing) {
            preview.state = null;
            return;
          }
          preview.state = kChatTrustPreviewRequest;
          final accountId = ref.read(selectedChatAccountIdProvider);
          if (accountId == null) return;
          final nav = ref.read(appNavProvider.notifier);
          nav.selectAccount(accountId);
          nav.selectSection(const SectionId('zentao.chat'));
        },
        width: s.xl5 + s.xs,
        height: s.xl5 + s.xs,
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Icon(
          previewing
              ? LucideIcons.shieldCheck300
              : LucideIcons.shieldQuestion300,
          size: s.xl3,
          color: context.colors.warning,
        ),
      ),
    );
  }
}
