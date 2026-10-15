import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The repository an MR belongs to, above its title as on GitLab:
/// "group / project › !42". The path opens the project in the browser.
class GitLabMrBreadcrumb extends StatelessWidget {
  const GitLabMrBreadcrumb({
    super.key,
    required this.projectPath,
    required this.reference,
    this.mrUrl,
  });

  /// `group/sub/project`.
  final String projectPath;

  /// The MR's iid, shown as `!42`.
  final String reference;

  /// The MR's web URL; the project's is its prefix before `/-/`.
  final String? mrUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.typography.secondary.copyWith(color: c.textSecondary);
    final projectUrl = _projectUrl(mrUrl);
    final label = projectPath.split('/').map((s) => s.trim()).join(' / ');
    final path = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return Row(
      children: [
        Icon(
          LucideIcons.folderGit2300,
          size: context.spacing.xl2,
          color: c.textTertiary,
        ),
        SizedBox(width: context.spacing.sm),
        Flexible(
          child: projectUrl == null
              ? path
              : Tooltip(
                  message: AppL10n.of(context).mrOpenProject,
                  child: HoverRegion(
                    builder: (context, hovered, _) => HoverSurface(
                      onTap: () => openLinkExternally(projectUrl),
                      tintOnHover: false,
                      borderRadius: BorderRadius.circular(context.radii.xs),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          decoration: hovered
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
          child: Icon(
            LucideIcons.chevronRight300,
            size: context.spacing.xl,
            color: c.textTertiary,
          ),
        ),
        Text('!$reference', style: style),
      ],
    );
  }
}

/// `https://host/group/web/-/merge_requests/42` → `https://host/group/web`.
String? _projectUrl(String? mrUrl) {
  if (mrUrl == null) return null;
  final cut = mrUrl.indexOf('/-/');
  return cut > 0 ? mrUrl.substring(0, cut) : null;
}
