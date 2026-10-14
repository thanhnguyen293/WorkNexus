import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_wallpaper_color.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../core/widgets/custom_color_dialog.dart';
import '../../../../core/widgets/hsv_color_fields.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/wallpaper_providers.dart';

/// How long a picked colour rests before it is saved: the background follows
/// every step of a drag at once, but only where it stops is written.
const _kSaveAfter = Duration(milliseconds: 400);

/// A free wallpaper colour, picked right in the chat style panel: the
/// colour area, the hue bar and the hex field. The chat background follows
/// the colour while it is dragged (a preview), and it is saved once the
/// picking pauses — or when the picker closes.
class ChatWallpaperCustomColor extends ConsumerStatefulWidget {
  const ChatWallpaperCustomColor({
    super.key,
    required this.initial,
    required this.doodles,
  });

  final Color initial;

  /// Whether the pattern is drawn over the colour.
  final bool doodles;

  @override
  ConsumerState<ChatWallpaperCustomColor> createState() =>
      _ChatWallpaperCustomColorState();
}

class _ChatWallpaperCustomColorState
    extends ConsumerState<ChatWallpaperCustomColor> {
  late var _color = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: hexOf(widget.initial));
  var _hexInvalid = false;
  Timer? _save;
  String? _pending;

  // Read up front: saving may still be due as the picker closes, when the
  // widget can no longer read providers.
  late final AppSettingsController _settings;
  late final ChatWallpaperPreview _preview;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(appSettingsProvider.notifier);
    _preview = ref.read(chatWallpaperPreviewProvider.notifier);
    // Another choice made meanwhile (a preset, the plain background, the
    // pattern switch, an image) wins over a colour still waiting to be saved.
    ref.listenManual(appSettingsProvider.select((s) => s.chatWallpaper), (
      _,
      saved,
    ) {
      if (_pending != null && saved != _pending) _drop();
    });
  }

  @override
  void dispose() {
    _save?.cancel();
    final pending = _pending;
    // Saved unless another choice cleared the preview (re-picking the colour
    // already saved changes no setting). Changing providers while the tree is
    // torn down is not allowed; do it right after.
    if (pending != null && _preview.shows(pending)) {
      Future(() => _commit(pending));
    }
    _hex.dispose();
    super.dispose();
  }

  void _drop() {
    _save?.cancel();
    _pending = null;
    _preview.clear();
  }

  void _commit(String wallpaper) {
    _settings.setChatWallpaper(wallpaper);
    _preview.clear();
    _pending = null;
  }

  void _show(HSVColor next) {
    final wallpaper = ChatWallpaperColor(
      hexOf(next.toColor()),
      doodles: widget.doodles,
    ).value;
    _pending = wallpaper;
    _preview.show(wallpaper);
    _save?.cancel();
    _save = Timer(_kSaveAfter, () => _commit(wallpaper));
  }

  /// From the area or the hue bar: the hex field follows.
  void _pick(HSVColor next) {
    setState(() {
      _color = next;
      _hex.text = hexOf(next.toColor());
      _hexInvalid = false;
    });
    _show(next);
  }

  /// From the hex field: the area and bar follow once it parses.
  void _typed(String text) {
    final parsed = parseHexColor(text);
    setState(() => _hexInvalid = parsed == null);
    if (parsed == null) return;
    final next = HSVColor.fromColor(parsed);
    // A grey has no hue of its own; keep the one in use.
    final kept = next.saturation == 0 ? next.withHue(_color.hue) : next;
    setState(() => _color = kept);
    _show(kept);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.spacing.md,
      children: [
        HsvSaturationValueArea(color: _color, onChanged: _pick),
        HsvHueBar(color: _color, onChanged: _pick),
        ConnectionTextField(
          label: l.colorHex,
          controller: _hex,
          errorText: _hexInvalid ? l.colorHexInvalid : null,
          onChanged: _typed,
        ),
      ],
    );
  }
}
