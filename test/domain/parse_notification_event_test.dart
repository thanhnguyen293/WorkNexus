import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/notifications/domain/usecases/parse_notification_event.dart';
import 'package:work_nexus/features/notifications/domain/value_objects/notification_action.dart';

void main() {
  const parse = ParseNotificationEvent();

  test('reads an English event', () {
    expect(parse('JunNg-VN-Flutter assigned Bug'), (
      actor: 'JunNg-VN-Flutter',
      action: NotificationAction.assigned,
    ));
    expect(parse('Luci-VN-Flutter finished Task'), (
      actor: 'Luci-VN-Flutter',
      action: NotificationAction.finished,
    ));
  });

  test('reads a Chinese event, its verb right after the name', () {
    expect(parse('Thanh-VN-Flutter指派了Bug'), (
      actor: 'Thanh-VN-Flutter',
      action: NotificationAction.assigned,
    ));
    expect(parse('Justin-VNTest关闭了任务'), (
      actor: 'Justin-VNTest',
      action: NotificationAction.closed,
    ));
  });

  test('keeps a name with spaces whole', () {
    expect(parse('Nguyen Van An resolved Bug'), (
      actor: 'Nguyen Van An',
      action: NotificationAction.resolved,
    ));
  });

  test('a verb inside a name does not count', () {
    expect(parse('closedbeta assigned Bug'), (
      actor: 'closedbeta',
      action: NotificationAction.assigned,
    ));
  });

  test('text without a known action is left as it is', () {
    expect(parse('JunNg mentioned you'), isNull);
    expect(parse('assigned Bug'), isNull);
    expect(parse('JunNg assigned'), isNull);
    expect(parse(''), isNull);
  });
}
