import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_labels.dart';

void main() {
  const mb = 1024 * 1024;

  test('a file at rest shows its size', () {
    expect(formatTransfer(364 * mb, null), '364.0 MB');
  });

  test('a transfer shows how much of the file has moved', () {
    expect(formatTransfer(100 * mb, 0.25), '25.0 MB / 100.0 MB');
    expect(formatTransfer(100 * mb, 0), '0 B / 100.0 MB');
    expect(formatTransfer(100 * mb, 1.4), '100.0 MB / 100.0 MB');
  });
}
