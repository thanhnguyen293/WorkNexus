import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/mappers/zentao_person_mapper.dart';

void main() {
  const departments = [
    {'id': 1, 'name': 'VN', 'parent': 0},
    {'id': 4, 'name': 'Flutter VN', 'parent': 1},
  ];

  test('maps a bare GET /users/{id} reply with its department path', () {
    final person = mapZenTaoPerson({
      'id': 98,
      'dept': '4',
      'role': 'dev',
      'email': 'tran@example.com',
      'mobile': '',
      'weixin': 'tran_wx',
      'join': '2021-03-15',
      'last': '2026-11-19 09:30:00',
      'address': '0000-00-00',
    }, departments: departments);

    expect(person.department, 'VN > Flutter VN');
    expect(person.role, 'dev');
    expect(person.email, 'tran@example.com');
    expect(person.mobile, isNull);
    expect(person.wechat, 'tran_wx');
    expect(person.joined, DateTime(2021, 3, 15));
    expect(person.lastLogin, DateTime(2026, 11, 19, 9, 30));
    expect(person.address, isNull);
  });

  test('unwraps a `user` reply, a role object and Unix-seconds dates', () {
    final person = mapZenTaoPerson({
      'user': {
        'role': {'code': 'qa', 'name': 'QA'},
        'join': '0000-00-00',
        'last': 1700000000,
      },
    });

    expect(person.role, 'qa');
    expect(person.joined, isNull);
    expect(
      person.lastLogin,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );
    expect(person.department, isNull);
  });
}
