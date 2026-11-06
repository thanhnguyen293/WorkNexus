import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = Uint8List.fromList([1, 2, 3]);

  void clipboardText(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return text == null ? null : {'text': text};
          }
          return null;
        });
  }

  HtmlEditingController controller({Uint8List? image}) =>
      HtmlEditingController(readImage: () async => image);

  bool hasImage(HtmlEditingController c, String url) => c.quill.document
      .toDelta()
      .toList()
      .any((op) => op.data is Map && (op.data! as Map)['image'] == url);

  test('a web "Copy image" (picture + its address) is uploaded', () async {
    clipboardText('https://example.com/cat.png');
    final c = controller(image: png);
    Uint8List? uploaded;
    c.onImagePaste = (bytes) async {
      uploaded = bytes;
      return 'https://zt/file-read-9.png';
    };

    expect(await c.pasteClipboardImage(), isTrue);
    expect(uploaded, png);
    expect(hasImage(c, 'https://zt/file-read-9.png'), isTrue);
  });

  test('a screenshot (picture, no text) is uploaded', () async {
    clipboardText(null);
    final c = controller(image: png)..onImagePaste = (_) async => 'u';

    expect(await c.pasteClipboardImage(), isTrue);
    expect(hasImage(c, 'u'), isTrue);
  });

  test('copied text with a picture is left to the editor', () async {
    clipboardText('Steps to reproduce');
    var calls = 0;
    final c = controller(image: png)
      ..onImagePaste = (_) async {
        calls++;
        return 'u';
      };

    expect(await c.pasteClipboardImage(), isFalse);
    expect(calls, 0);
  });

  test('no picture, or nowhere to upload it, leaves the paste', () async {
    clipboardText(null);
    expect(
      await (controller()..onImagePaste = (_) async => 'u')
          .pasteClipboardImage(),
      isFalse,
    );
    expect(await controller(image: png).pasteClipboardImage(), isFalse);
  });

  test('a failed upload pastes nothing (not the web copy)', () async {
    clipboardText('https://example.com/cat.png');
    final c = controller(image: png)..onImagePaste = (_) async => null;

    expect(await c.pasteClipboardImage(), isTrue);
    expect(c.quill.document.toPlainText().trim(), isEmpty);
  });
}
