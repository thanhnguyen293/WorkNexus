import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/app_name_service.dart';

void main() {
  late Directory dir;
  late AppNameService service;
  final toolTips = <String?>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('app_name_');
    toolTips.clear();
    service = AppNameService(
      file: () async => File('${dir.path}/sub/app_name.txt'),
      setTrayToolTip: (name) async => toolTips.add(name),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('has no name until one is given', () async {
    expect(await service.current(), isNull);
  });

  test('keeps a trimmed name and shows it on the tray', () async {
    await service.rename('  Acme Board ');
    expect(await service.current(), 'Acme Board');
    expect(toolTips.last, 'Acme Board');
  });

  test('a blank name gives the own name back', () async {
    await service.rename('Acme');
    await service.rename('   ');
    expect(await service.current(), isNull);
    expect(toolTips.last, isNull);
  });

  test('a name past the limit is cut', () async {
    await service.rename('x' * 100);
    expect((await service.current())!.length, AppNameService.maxLength);
  });

  test('a name that cannot be kept reports it and changes nothing', () async {
    // A file where the name's folder should be: the folder cannot be made.
    File('${dir.path}/sub').writeAsStringSync('');
    expect(await service.rename('Acme'), isFalse);
    expect(toolTips, isEmpty);
  });
}
