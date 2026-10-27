import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_text_labels.dart';

void main() {
  const bug = 'https://zentao.example.com/zentao/bug-view-6716.html';

  test('a Markdown link that repeats its address is one address', () {
    expect(chatUrls('[$bug]($bug)'), [bug]);
  });

  test('a link with text gives its address without the brackets', () {
    expect(chatUrls('see [the bug]($bug) now'), [bug]);
  });

  test('plain text and a Markdown link to one page are one address', () {
    expect(chatUrls('$bug and [again]($bug)'), [bug]);
  });

  test('a trailing slash, a fragment or the host case change nothing', () {
    expect(chatUrls('https://a.com/x https://a.com/x/'), ['https://a.com/x']);
    expect(chatUrls('https://a.com/x https://A.com/x#top'), [
      'https://a.com/x',
    ]);
  });

  test('different pages stay apart, in order', () {
    expect(chatUrls('https://a.com/1 https://a.com/2 https://a.com/1'), [
      'https://a.com/1',
      'https://a.com/2',
    ]);
    expect(chatUrls('https://a.com/?q=1 https://a.com/?q=2'), hasLength(2));
  });

  test('sentence punctuation stays out of the address', () {
    expect(chatUrls('open https://a.com/x, then https://b.com/y.'), [
      'https://a.com/x',
      'https://b.com/y',
    ]);
  });

  test('brackets inside an address stay, the one closing a link text goes', () {
    expect(chatUrls('https://g.com/issues?label_name[]=bug'), [
      'https://g.com/issues?label_name[]=bug',
    ]);
    expect(chatUrls('see http://[::1]:8080/ now'), ['http://[::1]:8080/']);
    expect(chatUrls('[https://a.com/x](https://a.com/x)'), ['https://a.com/x']);
  });
}
