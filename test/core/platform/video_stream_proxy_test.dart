import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/directory_size.dart';
import 'package:work_nexus/core/platform/video_stream_proxy.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('wn_stream_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('directoryBytes sums nested files; a missing dir is 0', () async {
    await File('${root.path}/a.bin').writeAsBytes(List.filled(10, 0));
    await Directory('${root.path}/seg').create();
    await File('${root.path}/seg/b.bin').writeAsBytes(List.filled(5, 0));

    expect(await directoryBytes(root), 15);
    expect(await directoryBytes(Directory('${root.path}/none')), 0);
  });

  test('an unstarted proxy reports and clears its cache dir', () async {
    final dir = Directory('${root.path}/videos');
    await Directory('${dir.path}/k').create(recursive: true);
    await File('${dir.path}/k/seg.mp4').writeAsBytes(List.filled(7, 0));
    final proxy = VideoStreamProxy(cacheDir: dir);

    expect(await proxy.sizeBytes(), 7);
    await proxy.clear();

    expect(await proxy.sizeBytes(), 0);
  });
}
