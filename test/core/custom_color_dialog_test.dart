import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/custom_color_dialog.dart';

void main() {
  test('parseHexColor reads #rrggbb in any case, with or without #', () {
    expect(parseHexColor('#3b82f6'), const Color(0xFF3B82F6));
    expect(parseHexColor('3B82F6'), const Color(0xFF3B82F6));
    expect(parseHexColor(' #3B82F6 '), const Color(0xFF3B82F6));
  });

  test('parseHexColor rejects malformed input', () {
    expect(parseHexColor(''), isNull);
    expect(parseHexColor('#3B82F'), isNull);
    expect(parseHexColor('#3B82F6FF'), isNull);
    expect(parseHexColor('#GGGGGG'), isNull);
  });

  test('hexOf writes an opaque colour as #RRGGBB', () {
    expect(hexOf(const Color(0xFF3B82F6)), '#3B82F6');
    expect(hexOf(const Color(0xFF00000A)), '#00000A');
  });
}
