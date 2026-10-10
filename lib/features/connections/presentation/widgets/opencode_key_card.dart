import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/opencode_credential.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../opencode_key_controller.dart';
import '../opencode_key_dialog.dart';
import 'opencode_credential_row.dart';

/// Settings section for the credentials the `opencode` CLI runs with — the key
/// behind ticket translation and dispatched coding agents. Reads and writes
/// OpenCode's own credential store, so a change here is what the CLI sees.
class OpenCodeKeyCard extends ConsumerWidget {
  const OpenCodeKeyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final credentials = ref.watch(openCodeCredentialsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.openCodeSection,
          style: context.typography.titleLg.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          l.openCodeSectionSubtitle,
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: context.spacing.xl2),
        Container(
          padding: EdgeInsets.all(context.spacing.xl2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (credentials) {
                AsyncData(:final value) => _CredentialList(result: value),
                AsyncError() => AppInlineNote(
                  text: l.openCodeCredentialsLoadFailed,
                  isError: true,
                ),
                _ => const AppInlineSpinner(),
              },
              SizedBox(height: context.spacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.outlinedNeutral(
                  onPressed: () => OpenCodeKeyDialog.show(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.key300, size: 16),
                      SizedBox(width: context.spacing.sm),
                      Text(l.openCodeAddKey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The loaded credentials, or the [Failure] that stopped us reading them.
class _CredentialList extends StatelessWidget {
  const _CredentialList({required this.result});

  final Result<List<OpenCodeCredential>> result;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return result.fold(
      (credentials) => credentials.isEmpty
          ? AppInlineNote(text: l.openCodeNoCredentials)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final credential in credentials)
                  OpenCodeCredentialRow(credential: credential),
              ],
            ),
      (failure) => AppInlineNote(text: failure.message, isError: true),
    );
  }
}
