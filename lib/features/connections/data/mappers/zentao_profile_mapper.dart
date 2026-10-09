import '../../domain/entities/zentao_department.dart';
import '../../domain/entities/zentao_profile.dart';

ZenTaoProfile mapZenTaoProfile(
  String accountId,
  Map<String, dynamic> json, {
  String? baseUrl,
}) {
  final raw = json['profile'];
  if (raw is! Map) throw const FormatException('ZenTao profile is missing');
  final profile = Map<String, dynamic>.from(raw);
  String? value(String key) {
    final text = profile[key]?.toString().trim();
    return text == null || text.isEmpty || text == '0000-00-00' ? null : text;
  }

  final role = profile['role'];
  final roleName = role is Map ? role['name']?.toString() : role?.toString();
  final avatar = value('avatar');
  final avatarUrl = avatar == null
      ? null
      : Uri.tryParse(baseUrl ?? '')?.resolve(avatar).toString() ?? avatar;
  return ZenTaoProfile(
    accountId: accountId,
    account: value('account') ?? '',
    realname: value('realname') ?? value('account') ?? '',
    userId: int.tryParse(value('id') ?? ''),
    departmentId: int.tryParse(value('dept') ?? ''),
    roleCode: role is Map ? role['code']?.toString() : null,
    avatarUrl: avatarUrl,
    gender: value('gender'),
    department: value('departmentPath') ?? value('deptName'),
    role: roleName?.trim().isEmpty == true ? null : roleName,
    joined: value('join'),
    privilege: value('privilege') ?? value('group'),
    email: value('email'),
    mobile: value('mobile'),
    phone: value('phone'),
    wechat: value('weixin'),
    qq: value('qq'),
    zipcode: value('zipcode'),
    address: value('address'),
    svnGitAccount: value('commiter'),
    skype: value('skype'),
    visits: int.tryParse(value('visits') ?? ''),
    whatsapp: value('whatsapp'),
    lastLogin: value('last'),
    slack: value('slack'),
    lastIp: value('ip'),
    dingding: value('dingding'),
  );
}

List<ZenTaoDepartment> mapZenTaoDepartments(
  List<Map<String, dynamic>> json,
) => [
  for (final item in json)
    if (int.tryParse('${item['id']}') case final int id)
      ZenTaoDepartment(
        id: id,
        name: item['name']?.toString() ?? '',
        parentId: int.tryParse('${item['parent']}') ?? 0,
        path: zenTaoDepartmentPath(id, json) ?? item['name']?.toString() ?? '',
      ),
];

/// Returns a readable hierarchy (e.g. "VN > Flutter VN") for a department id.
String? zenTaoDepartmentPath(int id, List<Map<String, dynamic>> departments) {
  if (id <= 0) return null;
  final byId = <int, Map<String, dynamic>>{};
  for (final dept in departments) {
    final deptId = int.tryParse('${dept['id']}');
    if (deptId != null) byId[deptId] = dept;
  }
  final names = <String>[];
  final seen = <int>{};
  var current = id;
  while (current > 0 && seen.add(current)) {
    final department = byId[current];
    if (department == null) break;
    final name = department['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) names.add(name);
    current = int.tryParse('${department['parent']}') ?? 0;
  }
  return names.isEmpty ? null : names.reversed.join(' > ');
}
