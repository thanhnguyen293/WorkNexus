import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_certificate_card.dart';

void main() {
  test('a SHA-256 fingerprint reads as four lines of eight bytes', () {
    final bytes = [
      for (var i = 0; i < 32; i++) i.toRadixString(16).padLeft(2, '0'),
    ];
    final lines = fingerprintLines(bytes.join(':')).split('\n');

    expect(lines, hasLength(4));
    expect(lines.first, '00:01:02:03:04:05:06:07');
    expect(lines.last, '18:19:1a:1b:1c:1d:1e:1f');
  });

  test('a short fingerprint stays on one line', () {
    expect(fingerprintLines('AE:C6:E8'), 'AE:C6:E8');
  });

  test('a certificate is named by its common name', () {
    expect(certificateName('/C=CN/ST=SD/CN=zentao.example'), 'zentao.example');
    expect(certificateName('CN=cnezsoft, O=Nature'), 'cnezsoft');
    expect(certificateName('O=Nature'), 'O=Nature', reason: 'no CN: as is');
  });
}
