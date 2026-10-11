import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/is_single_emoji.dart';

void main() {
  const isSingle = IsSingleEmoji();

  test('one known emoji is single, whitespace and selectors aside', () {
    expect(isSingle('😀'), isTrue);
    expect(isSingle('  👍 \n'), isTrue);
    expect(isSingle('❤️'), isTrue);
    expect(isSingle('❤'), isTrue);
    expect(isSingle('👍🏽'), isTrue);
    expect(isSingle('🇻🇳'), isTrue);
  });

  test('text, several emoji or nothing is not', () {
    expect(isSingle(''), isFalse);
    expect(isSingle('   '), isFalse);
    expect(isSingle('ok'), isFalse);
    expect(isSingle('😀😀'), isFalse);
    expect(isSingle('😀 ok'), isFalse);
    expect(isSingle(':smile:'), isFalse);
  });
}
