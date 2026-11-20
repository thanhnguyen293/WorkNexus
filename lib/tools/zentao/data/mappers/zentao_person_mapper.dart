import '../../../../core/domain/entities/person_profile.dart';
import 'zentao_profile_mapper.dart';

/// A colleague from `GET /users/{id}` as a [PersonProfile]. The reply is the
/// bare user on most servers, wrapped in `user` or `profile` on some; the
/// department path comes from [departments] (`GET /departments`).
PersonProfile mapZenTaoPerson(
  Map<String, dynamic> json, {
  List<Map<String, dynamic>> departments = const [],
}) {
  final wrapped = json['user'] ?? json['profile'];
  final user = wrapped is Map ? Map<String, dynamic>.from(wrapped) : json;
  String? value(String key) {
    final text = user[key]?.toString().trim();
    return text == null || text.isEmpty || text.startsWith('0000-00-00')
        ? null
        : text;
  }

  final role = user['role'];
  final deptId = int.tryParse(value('dept') ?? '') ?? 0;
  return PersonProfile(
    department:
        zenTaoDepartmentPath(deptId, departments) ??
        value('deptName') ??
        value('departmentPath'),
    role: switch (role) {
      final Map<dynamic, dynamic> r => _blank(r['code'] ?? r['name']),
      _ => _blank(role),
    },
    email: value('email'),
    mobile: value('mobile'),
    phone: value('phone'),
    gender: value('gender'),
    address: value('address'),
    joined: _date(user['join']),
    lastLogin: _date(user['last']),
    wechat: value('weixin'),
    qq: value('qq'),
    skype: value('skype'),
    slack: value('slack'),
    whatsapp: value('whatsapp'),
    dingding: value('dingding'),
  );
}

String? _blank(Object? v) {
  final text = v?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// ZenTao sends dates as `2024-03-01`, `2024-03-01 09:30:00`, ISO strings or
/// Unix seconds; `0000-00-00` and 0 mean "never".
DateTime? _date(Object? v) {
  if (v is num) {
    return v <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
  }
  final text = _blank(v);
  if (text == null || text.startsWith('0000')) return null;
  if (int.tryParse(text) case final int seconds) return _date(seconds);
  return DateTime.tryParse(text)?.toLocal();
}
