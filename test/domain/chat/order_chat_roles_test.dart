import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/order_chat_roles.dart';

void main() {
  const order = OrderChatRoles();

  test('present roles, most senior first, custom and none last', () {
    expect(
      order(['dev', 'top', null, 'designer', 'qa', 'td', 'dev', ' ', 'pm']),
      ['top', 'td', 'pm', 'dev', 'qa', 'designer', ''],
    );
  });

  test('nobody, no tabs', () {
    expect(order(const []), isEmpty);
  });
}
