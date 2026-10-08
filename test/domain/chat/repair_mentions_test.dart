import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';

void main() {
  test('drops the name tail the official client leaves after a mention', () {
    expect(
      ParseMessageContent.repairMentions(
        'hi [@Felix-VN-Flutter](@#35)-VN-Flutter, ok [@An](@#2) x',
      ),
      'hi [@Felix-VN-Flutter](@#35), ok [@An](@#2) x',
    );
  });

  test('unwraps a mention nested in another link to the same user', () {
    expect(
      ParseMessageContent.repairMentions(
        '[[@Thanh-VN-Flutter](@#40)-VN-Flutter](@#40) ABC',
      ),
      '[@Thanh-VN-Flutter](@#40) ABC',
    );
  });

  test('drops a tail that starts with a space', () {
    expect(
      ParseMessageContent.repairMentions(
        'anh [@Tom Nguyen-VN-go](@#41) Nguyen-VN-go ok',
      ),
      'anh [@Tom Nguyen-VN-go](@#41) ok',
    );
  });

  test('keeps text that is not a repeated tail', () {
    const text = '[@Dyno-VN-Flutter](@#31) abc [@A-B](@#3)-C';
    expect(ParseMessageContent.repairMentions(text), text);
  });
}
