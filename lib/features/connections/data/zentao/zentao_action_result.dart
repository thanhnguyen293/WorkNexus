import 'package:dio/dio.dart';

import 'zentao_form_parsing.dart';

/// Throws unless ZenTao processed classic action [action] (`bug-resolve`,
/// `task-start`…).
///
/// Unlike the REST channel, a POST that ZenTao did NOT process comes back as
/// the action page's HTML (a String) or a login redirect rather than a
/// `{result: 'success'}` JSON object — so anything that isn't a non-failing
/// JSON object is a failure. ZenTao 18.x wraps every `.json` reply as
/// `{status: 'success', data: '<json>'}` — a refused action too, with its
/// `{result: 'fail', message}` inside — so the unwrapped reply is checked.
void ensureZenTaoActionOk(Response<dynamic> resp, String action) {
  final code = resp.statusCode ?? 0;
  final reply = classicPayload(resp.data);
  if (code < 400 && reply != null && !_refused(reply)) return;
  final detail = reply == null
      ? 'ZenTao did not process the action '
            '(auth/permission, CSRF, or the action does not exist)'
      : _flatten(reply['message'] ?? reply['error']).join(' ');
  throw DioException(
    requestOptions: resp.requestOptions,
    response: resp,
    message:
        'ZenTao $action failed (HTTP $code)'
        '${detail.isEmpty ? '' : ': $detail'}',
  );
}

bool _refused(Map<String, dynamic> reply) =>
    reply['result']?.toString() == 'fail' ||
    const {'fail', 'failed'}.contains(reply['status']?.toString()) ||
    // 18.x answers a signed-out request by sending the client to log in.
    (reply['locate']?.toString().contains('user-login') ?? false);

/// ZenTao's reason: a string, or field errors as a map or list
/// (`{left: ['must be more than 0']}`).
Iterable<String> _flatten(Object? raw) sync* {
  switch (raw) {
    case null:
      return;
    case final Map<Object?, Object?> map:
      for (final v in map.values) {
        yield* _flatten(v);
      }
    case final List<Object?> list:
      for (final v in list) {
        yield* _flatten(v);
      }
    default:
      final text = raw.toString().trim();
      if (text.isNotEmpty) yield text;
  }
}
