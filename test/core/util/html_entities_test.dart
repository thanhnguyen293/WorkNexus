import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/html_entities.dart';

void main() {
  test('named and numeric references become characters', () {
    expect(
      decodeHtmlEntities(
        'instead of &quot;Not enough gas fee&quot; &amp; more',
      ),
      'instead of "Not enough gas fee" & more',
    );
    expect(decodeHtmlEntities('it&#39;s &#x2F; &lt;b&gt;'), "it's / <b>");
  });

  test('plain text and unknown names stay as written', () {
    expect(decodeHtmlEntities('Tiếng Việt'), 'Tiếng Việt');
    expect(decodeHtmlEntities('&unknown; & alone'), '&unknown; & alone');
  });
}
