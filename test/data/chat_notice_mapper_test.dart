import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/mappers/chat_mappers.dart';

Map<String, Object?> _message({Object? type}) => {
  'gid': 'm1',
  'cgid': 'g1',
  'id': 7,
  'user': 21,
  'date': 1760000000,
  'contentType': 'text',
  'content': '[@Jun](@#21) 邀请 [@Sang](@#112) 加入了讨论组。',
  'type': ?type,
};

void main() {
  test('a broadcast message is stored as a notice', () {
    final row = messageFromXxd('acc', _message(type: 'broadcast'));

    expect(row.broadcast, const Value(true));
  });

  test('a normal message is not a notice', () {
    final row = messageFromXxd('acc', _message(type: 'normal'));

    expect(row.broadcast, const Value(false));
  });

  test('a copy without a type leaves a stored flag alone', () {
    final row = messageFromXxd('acc', _message());

    expect(row.broadcast, const Value<bool>.absent());
  });
}
