import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_search_field.dart';
import '../providers/chat_providers.dart';

/// The chat search box. Its text lives in [chatSearchProvider] (the list
/// filters by it), so a box rebuilt after switching views starts from that
/// text rather than empty over a still-filtered list.
class ChatSearchField extends ConsumerStatefulWidget {
  const ChatSearchField({super.key, required this.hint});

  final String hint;

  @override
  ConsumerState<ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends ConsumerState<ChatSearchField> {
  late final _text = TextEditingController(text: ref.read(chatSearchProvider));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppSearchField(controller: _text, hint: widget.hint, onChanged: _search);

  void _search(String text) =>
      ref.read(chatSearchProvider.notifier).state = text;
}
