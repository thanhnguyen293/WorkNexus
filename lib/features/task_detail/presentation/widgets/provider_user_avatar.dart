import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

typedef AvatarLoader = Future<Uint8List?> Function(String url);

class ProviderUserAvatar extends StatelessWidget {
  const ProviderUserAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.imageLoader,
  });

  final String name;
  final String? avatarUrl;
  final AvatarLoader imageLoader;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProviderAvatarImage(
          name: name,
          avatarUrl: avatarUrl,
          imageLoader: imageLoader,
        ),
        SizedBox(width: context.spacing.sm),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.body.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class ProviderAvatarImage extends StatefulWidget {
  const ProviderAvatarImage({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.imageLoader,
  });

  final String name;
  final String? avatarUrl;
  final AvatarLoader imageLoader;

  @override
  State<ProviderAvatarImage> createState() => _ProviderAvatarImageState();
}

class _ProviderAvatarImageState extends State<ProviderAvatarImage> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProviderAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.imageLoader != widget.imageLoader) {
      _load();
    }
  }

  void _load() {
    final url = widget.avatarUrl;
    _bytes = url == null || url.isEmpty ? null : widget.imageLoader(url);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: context.spacing.xl5 + context.spacing.xs,
      child: ClipOval(
        child: _bytes == null
            ? _AvatarFallback(name: widget.name)
            : FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  return bytes == null || bytes.isEmpty
                      ? _AvatarFallback(name: widget.name)
                      : Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              _AvatarFallback(name: widget.name),
                        );
                },
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ColoredBox(
      color: context.colors.selectionFill,
      child: Center(
        child: Text(
          initial,
          style: context.typography.captionStrong.copyWith(
            color: context.colors.accent,
          ),
        ),
      ),
    );
  }
}
