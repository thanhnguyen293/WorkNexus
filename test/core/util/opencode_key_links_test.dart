import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/opencode_key_links.dart';

void main() {
  test('known providers map to their key page, ignoring case and spaces', () {
    expect(
      openCodeKeyUrl(' Anthropic '),
      'https://console.anthropic.com/settings/keys',
    );
    expect(openCodeKeyUrl('openai'), 'https://platform.openai.com/api-keys');
  });

  test('unknown or empty providers fall back to the OpenCode console', () {
    expect(openCodeKeyUrl(''), kOpenCodeConsoleUrl);
    expect(openCodeKeyUrl('something-else'), kOpenCodeConsoleUrl);
  });
}
