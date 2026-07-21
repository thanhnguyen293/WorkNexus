import 'package:flutter/material.dart';

/// Parses provider-owned `#RRGGBB` / `#RGB` values into opaque UI colors.
Color? providerColorFromHex(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((character) => '$character$character').join();
  }
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
