import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/encode_mentions.dart';

void main() {
  const encode = EncodeMentions();

  test('encodes inserted mentions, longest name first', () {
    expect(
      encode('hi @An Nguyen and @An, see @all', {'An': 1, 'An Nguyen': 2}),
      'hi [@An Nguyen](@#2) and [@An](@#1), see @all',
    );
  });

  test('leaves other @words and partial names alone', () {
    expect(encode('mail a@b.com @Anna', {'An': 1}), 'mail a@b.com @Anna');
  });
}
