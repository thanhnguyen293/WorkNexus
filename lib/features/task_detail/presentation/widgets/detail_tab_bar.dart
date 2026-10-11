import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/util/translation_languages.dart';
import '../../../../l10n/app_localizations.dart';
import '../detail_providers.dart';
import 'detail_underline_tabs.dart';

/// The detail panel's horizontal tab strip.
class DetailTabBar extends ConsumerWidget {
  const DetailTabBar({super.key, required this.current});
  final DetailTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final lang = translationLanguageFor(
      ref.watch(appSettingsProvider.select((s) => s.translationLang)),
    );
    final labels = {
      DetailTab.original: l.original,
      DetailTab.translation: '${lang.flag} ${lang.nativeName}',
    };
    return DetailUnderlineTabs<DetailTab>(
      labels: labels,
      current: current,
      onSelect: (tab) => ref.read(detailTabProvider.notifier).set(tab),
    );
  }
}
