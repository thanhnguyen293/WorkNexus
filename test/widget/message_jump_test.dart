import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/list_extent_estimate.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_jump.dart';
import 'package:work_nexus/features/chat/presentation/widgets/steady_extent_child_delegate.dart';

/// A row that, when [grows], gets taller a moment after it is first built —
/// as one with an image or a card does the first time it is shown.
class _Row extends StatefulWidget {
  const _Row({super.key, required this.label, required this.grows});

  final String label;
  final bool grows;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  late double _height = 40;
  Timer? _grow;

  @override
  void initState() {
    super.initState();
    if (widget.grows) {
      _grow = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _height = 220);
      });
    }
  }

  @override
  void dispose() {
    _grow?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: _height, child: Text(widget.label));
}

ChatMessage _message(int i) => ChatMessage(
  accountId: 'a',
  gid: 'm$i',
  chatGid: 'g',
  senderId: 1,
  sentAt: DateTime(2026, 10, 2).add(Duration(minutes: i)),
  content: MessageContent.text('message $i'),
  isMine: false,
  serverId: i,
  index: i,
);

void main() {
  const target = 'm150';
  late List<ChatMessage> rows;
  late MessageJump jump;
  late ScrollController scroll;
  late StateSetter rebuild;
  late ListExtentEstimate extent;

  /// A reversed list like the chat's: newest (highest number) first.
  Future<void> pumpList(WidgetTester tester, {Set<String> grows = const {}}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return ListView.custom(
                    controller: scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    childrenDelegate: SteadyExtentChildDelegate(
                      (context, i) => _Row(
                        key: rows[i].gid == jump.targetGid
                            ? jump.anchor
                            : ValueKey(rows[i].gid),
                        label: rows[i].gid,
                        grows: grows.contains(rows[i].gid),
                      ),
                      estimate: extent,
                      childCount: rows.length,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

  Future<bool> reveal(WidgetTester tester) async {
    final found = jump.reveal(
      scroll,
      gid: target,
      rows: () => rows,
      rebuild: () => rebuild(() {}),
    );
    await tester.pumpAndSettle();
    return found;
  }

  void expectCentred(WidgetTester tester) {
    final row = tester.getRect(find.text(target));
    final list = tester.getRect(find.byType(ListView));
    expect(row.center.dy, moreOrLessEquals(list.center.dy, epsilon: 2));
  }

  setUp(() {
    // Newest first, as the reversed chat list holds them.
    rows = [for (var i = 299; i >= 0; i--) _message(i)];
    jump = MessageJump();
    scroll = ScrollController();
    extent = ListExtentEstimate();
  });

  testWidgets('stays centred while the rows below it grow', (tester) async {
    await pumpList(tester, grows: {for (var i = 151; i < 160; i++) 'm$i'});
    expect(await reveal(tester), isTrue);
    expectCentred(tester);

    // The rows shown for the first time below it get taller.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectCentred(tester);
  });

  testWidgets('stays centred when newer messages are added below it', (
    tester,
  ) async {
    await pumpList(tester);
    expect(await reveal(tester), isTrue);

    // The jump window loads the messages after it, under it.
    rebuild(
      () => rows = [for (var i = 340; i >= 300; i--) _message(i), ...rows],
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expectCentred(tester);
  });

  testWidgets('lets go once the user scrolls', (tester) async {
    await pumpList(tester, grows: {for (var i = 151; i < 160; i++) 'm$i'});
    expect(await reveal(tester), isTrue);

    jump.release();
    final before = scroll.offset;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(scroll.offset, before);
  });
}
