import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/list_extent_estimate.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_jump.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_jump_sliver.dart';
import 'package:work_nexus/features/chat/presentation/widgets/steady_extent_child_delegate.dart';

/// A row that, when [grows], gets taller a moment after it is first built —
/// as one with an image or a card does the first time it is shown.
/// How many times each row's state was created: a row rebuilt from scratch
/// (its images and cards loading again) shows up here.
final _created = <String, int>{};

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
    _created.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
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
  const target = 150;
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
                  return CustomScrollView(
                    controller: scroll,
                    reverse: true,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        sliver: MessageJumpSliver(
                          jump: jump,
                          rows: rows,
                          sliver: SliverList(
                            delegate: SteadyExtentChildDelegate(
                              (context, i) => _Row(
                                key: ValueKey(rows[i].gid),
                                label: rows[i].gid,
                                grows: grows.contains(rows[i].gid),
                              ),
                              estimate: extent,
                              childCount: rows.length,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

  Future<bool> reveal(WidgetTester tester, {int id = target}) async {
    final found = jump.reveal(scroll, serverId: id, rows: rows);
    await tester.pumpAndSettle();
    return found;
  }

  void expectCentred(WidgetTester tester, {int id = target}) {
    final row = tester.getRect(find.text('m$id'));
    final list = tester.getRect(find.byType(CustomScrollView));
    expect(row.center.dy, moreOrLessEquals(list.center.dy, epsilon: 2));
  }

  setUp(() {
    _created.clear();
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

  testWidgets('a far row is centred in the first frame, none on the way', (
    tester,
  ) async {
    await pumpList(tester);
    unawaited(jump.reveal(scroll, serverId: target, rows: rows));
    await tester.pump();
    expectCentred(tester);
    // Rows between the newest and the target were never built.
    expect(_created.containsKey('m100'), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('aimed before its rows arrive, they show it centred at once', (
    tester,
  ) async {
    final all = rows;
    rows = all.sublist(0, 40);
    await pumpList(tester);
    jump.aim(target);
    await tester.pump();
    // The old rows stay shown while the window loads.
    expect(find.text('m299'), findsOneWidget);

    rebuild(() => rows = all.sublist(120, 180));
    await tester.pump();
    expectCentred(tester);
    expect(await reveal(tester), isTrue);
    expectCentred(tester);
  });

  testWidgets('a row nearby glides there and keeps its state', (tester) async {
    await pumpList(tester);
    expect(await reveal(tester, id: 290), isTrue);
    expectCentred(tester, id: 290);
    expect(_created['m290'], 1);
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
