import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cookie_site.dart';

/// The sites a browser profile has cookies for, each with a checkbox: a
/// search narrows them, and the picks can be set all at once.
class CookieSitePicker extends StatefulWidget {
  const CookieSitePicker({
    super.key,
    required this.sites,
    required this.picked,
    required this.onChanged,
  });

  final List<CookieSite> sites;
  final Set<String> picked;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<CookieSitePicker> createState() => _CookieSitePickerState();
}

class _CookieSitePickerState extends State<CookieSitePicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String site) => widget.onChanged(
    widget.picked.contains(site)
        ? ({...widget.picked}..remove(site))
        : {...widget.picked, site},
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final query = _query.text.trim().toLowerCase();
    final shown = [
      for (final site in widget.sites)
        if (query.isEmpty || site.site.contains(query)) site,
    ];
    if (widget.sites.isEmpty) {
      return Text(
        l.miniAppCookiesNoSites,
        style: context.typography.caption.copyWith(color: c.textTertiary),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: s.md,
      children: [
        Row(
          spacing: s.md,
          children: [
            Expanded(
              child: AppSearchField(
                controller: _query,
                hint: l.miniAppCookiesSearch,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            AppButton.textNeutral(
              size: AppButtonSize.small,
              onPressed: () => widget.onChanged({
                ...widget.picked,
                for (final site in shown) site.site,
              }),
              child: Text(l.miniAppCookiesSelectAll),
            ),
            AppButton.textNeutral(
              size: AppButtonSize.small,
              isDisabled: widget.picked.isEmpty,
              onPressed: () => widget.onChanged(const {}),
              child: Text(l.miniAppCookiesSelectNone),
            ),
          ],
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: shown.length,
            itemBuilder: (context, i) => _SiteRow(
              site: shown[i],
              picked: widget.picked.contains(shown[i].site),
              onToggle: () => _toggle(shown[i].site),
            ),
          ),
        ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.site,
    required this.picked,
    required this.onToggle,
  });

  final CookieSite site;
  final bool picked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
        child: Row(
          spacing: s.md,
          children: [
            Checkbox(value: picked, onChanged: (_) => onToggle()),
            Expanded(
              child: Text(
                site.site,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(color: c.textPrimary),
              ),
            ),
            if (site.usedByMiniApp)
              TintedPill(color: c.accent, label: l.miniAppCookiesUsedByApp),
            Text(
              l.miniAppCookiesSiteCount(site.cookies.length),
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
