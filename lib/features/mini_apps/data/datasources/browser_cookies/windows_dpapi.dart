import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Decrypts [data] the way Windows DPAPI protected it for the signed-in
/// user; null when Windows refuses. Only callable on Windows.
typedef Unprotect = Uint8List? Function(Uint8List data);

final class _Blob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _UnprotectNative =
    Int32 Function(
      Pointer<_Blob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_Blob>,
    );
typedef _UnprotectDart =
    int Function(
      Pointer<_Blob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_Blob>,
    );
typedef _LocalFree = Pointer<Void> Function(Pointer<Void>);

/// [Unprotect] through `CryptUnprotectData`, never showing a prompt.
Uint8List? windowsUnprotect(Uint8List data) {
  final unprotect = DynamicLibrary.open(
    'crypt32.dll',
  ).lookupFunction<_UnprotectNative, _UnprotectDart>('CryptUnprotectData');
  final localFree = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<_LocalFree, _LocalFree>('LocalFree');
  const uiForbidden = 0x1;
  final bytes = calloc<Uint8>(data.length);
  final input = calloc<_Blob>();
  final output = calloc<_Blob>();
  try {
    bytes.asTypedList(data.length).setAll(0, data);
    input.ref
      ..cbData = data.length
      ..pbData = bytes;
    final ok = unprotect(
      input,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      uiForbidden,
      output,
    );
    if (ok == 0) return null;
    final plain = Uint8List.fromList(
      output.ref.pbData.asTypedList(output.ref.cbData),
    );
    localFree(output.ref.pbData.cast());
    return plain;
  } finally {
    calloc
      ..free(bytes)
      ..free(input)
      ..free(output);
  }
}
