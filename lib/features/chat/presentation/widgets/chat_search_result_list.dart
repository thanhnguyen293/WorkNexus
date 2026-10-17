import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';

/// The search panel's results. When more are stored, scrolling to the end
/// asks for the next page through [onLoadMore].
class ChatSearchResultList extends StatelessWidget {
  const ChatSearchResultList({
    super.key,
    required this.messages,
    required this.hasMore,
    required this.onLoadMore,
    required this.itemBuilder,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, ChatMessage message) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      itemCount: messages.length + (hasMore ? 1 : 0),
      separatorBuilder: (context, _) => Divider(
        height: 1,
        thickness: context.borders.hairline,
        color: c.border,
      ),
      itemBuilder: (context, index) => index < messages.length
          ? itemBuilder(context, messages[index])
          : _LoadMore(onLoadMore: onLoadMore),
    );
  }
}

/// The row after the last result: built once the list scrolls to it, it
/// asks for the next page and spins until that page replaces it.
class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.onLoadMore});

  final VoidCallback onLoadMore;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    // Not during build: asking changes provider state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.spacing.sm),
    child: Center(
      child: SizedBox.square(
        dimension: context.spacing.md,
        child: CircularProgressIndicator(
          strokeWidth: context.borders.thick,
          color: context.colors.accent,
        ),
      ),
    ),
  );
}
