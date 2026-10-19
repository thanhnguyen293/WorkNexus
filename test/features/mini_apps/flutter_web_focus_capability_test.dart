import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_flutter_web_focus_capability.dart';

void main() {
  final capability = MiniAppFlutterWebFocusCapability();

  test('runs before the page, so it is in place when the page starts', () {
    expect(
      capability.userScript.injectionTime,
      UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  });

  test('acts only on a Flutter web page', () {
    final source = capability.userScript.source;
    expect(source, contains('flutter-view'));
    expect(source, contains('isFlutter()'));
  });

  test('hides the web view losing focus, not the page moving it', () {
    final source = capability.userScript.source;
    // Events at the window, and any blur while the document has no focus, are
    // held back from the page; a blur with the document focused goes through.
    expect(source, contains('document.hasFocus()'));
    expect(source, contains('stopImmediatePropagation'));
    expect(source, contains("'blur'"));
    expect(source, contains("'focusout'"));
    expect(source, contains("'focus'"));
  });
}
