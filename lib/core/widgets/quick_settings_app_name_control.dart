import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../platform/app_name_providers.dart';
import '../platform/app_name_service.dart';
import '../theme/app_typography.dart';
import 'app_input_decoration.dart';

/// The name the app goes by, typed in place; kept when the field is submitted
/// or loses focus, and emptied to go back to the app's own name.
class QuickSettingsAppNameControl extends ConsumerStatefulWidget {
  const QuickSettingsAppNameControl({super.key});

  @override
  ConsumerState<QuickSettingsAppNameControl> createState() => _State();
}

class _State extends ConsumerState<QuickSettingsAppNameControl> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(appNameProvider).asData?.value ?? '';
    // A name that arrives after the first frame (read from disk) fills the
    // field unless the user is already typing.
    ref.listenManual(appNameProvider, (_, next) {
      final name = next.asData?.value ?? '';
      if (!_focus.hasFocus && _controller.text != name) {
        _controller.text = name;
      }
    });
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final saved = ref.read(appNameProvider).asData?.value ?? '';
    final typed = _controller.text.trim();
    if (typed != saved) {
      ref.read(appNameProvider.notifier).rename(typed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLength: AppNameService.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: context.typography.body,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: appInputDecoration(
        context,
        hint: AppConfig.appName,
      ).copyWith(counterText: ''),
    );
  }
}
