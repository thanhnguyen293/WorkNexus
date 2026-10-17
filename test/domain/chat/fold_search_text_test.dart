import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/fold_search_text.dart';

void main() {
  const fold = FoldSearchText();

  test('drops case and Vietnamese diacritics', () {
    expect(fold('Đường Phố HỒ CHÍ MINH'), 'duong pho ho chi minh');
    expect(fold('Việt Nam ưu tiên'), 'viet nam uu tien');
  });

  test('drops combining marks of decomposed text', () {
    // "Việt" typed as V, i, e, U+0323, U+0302, t.
    expect(fold('Việt'), 'viet');
  });

  test('collapses whitespace', () {
    expect(fold('  xin \n  chào  '), 'xin chao');
  });

  group('ofMessage', () {
    test('is null for a non-text message', () {
      expect(fold.ofMessage('image', '{"name":"a.png"}'), isNull);
      expect(fold.ofMessage('code', 'print(1)'), isNull);
    });

    test('keeps a mention as its name only', () {
      expect(
        fold.ofMessage('plain', 'hỏi [@Thành](@#40) nhé'),
        'hoi @thanh nhe',
      );
    });

    test('decodes emoji shortnames and entities', () {
      expect(fold.ofMessage('plain', 'ok :thumbsup:'), 'ok 👍');
      expect(fold.ofMessage('plain', 'ok &#x1F600;'), 'ok 😀');
    });

    test('drops Markdown emphasis but keeps underscores', () {
      expect(
        fold.ofMessage('text', '**Gấp**: sửa `snake_case` ~~cũ~~'),
        'gap: sua snake_case cu',
      );
      expect(
        fold.ofMessage('text', 'xem [docs](https://x.io)'),
        'xem docs https://x.io',
      );
    });

    test('leaves Markdown marks in a plain message', () {
      expect(fold.ofMessage('plain', '2*3'), '2*3');
    });
  });
}
