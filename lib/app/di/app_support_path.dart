import 'package:path_provider/path_provider.dart';

/// The path of [name] in the app's support folder.
Future<String> appSupportPath(String name) async =>
    '${(await getApplicationSupportDirectory()).path}/$name';
