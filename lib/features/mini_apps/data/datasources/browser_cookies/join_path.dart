import 'dart:io';

/// [parts] joined with this system's separator; a part may hold `/` itself,
/// which Windows takes too.
String joinPath(List<String> parts) => parts.join(Platform.pathSeparator);
