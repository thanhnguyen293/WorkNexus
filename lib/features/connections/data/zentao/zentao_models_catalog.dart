part of 'zentao_models.dart';

/// A ZenTao product from `GET /products`.
class ZenTaoProduct {
  const ZenTaoProduct({required this.id, required this.name});

  final String id;
  final String name;

  factory ZenTaoProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? id;
    return ZenTaoProduct(id: id, name: name);
  }
}

/// `GET /products` → `{ total, products: [...] }`.
class ZenTaoProductsResponse {
  const ZenTaoProductsResponse({required this.total, required this.products});

  final int total;
  final List<ZenTaoProduct> products;

  factory ZenTaoProductsResponse.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    return ZenTaoProductsResponse(
      total: zentaoInt(json['total']) ?? 0,
      products: [
        if (rawProducts is List)
          for (final product in rawProducts)
            if (product is Map)
              ZenTaoProduct.fromJson(Map<String, dynamic>.from(product)),
      ],
    );
  }
}

/// `GET /products/{id}/bugs` → `{ total, bugs: [...] }`.
class ZenTaoProductBugsResponse {
  const ZenTaoProductBugsResponse({required this.total, required this.bugs});

  final int total;
  final List<ZenTaoEntity> bugs;

  factory ZenTaoProductBugsResponse.fromJson(Map<String, dynamic> json) {
    final rawBugs = json['bugs'];
    return ZenTaoProductBugsResponse(
      total: zentaoInt(json['total']) ?? 0,
      bugs: [
        if (rawBugs is List)
          for (final bug in rawBugs)
            if (bug is Map)
              ZenTaoEntity.fromJson(Map<String, dynamic>.from(bug)),
      ],
    );
  }
}

/// A ZenTao project from `GET /projects`. Projects group executions, which in
/// turn hold tasks (parallel to how products hold bugs).
class ZenTaoProject {
  const ZenTaoProject({required this.id, required this.name});

  final String id;
  final String name;

  factory ZenTaoProject.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = (json['name'] ?? json['title'])?.toString() ?? id;
    return ZenTaoProject(id: id, name: name);
  }
}

/// `GET /projects` → `{ total, projects: [...] }`.
class ZenTaoProjectsResponse {
  const ZenTaoProjectsResponse({required this.total, required this.projects});

  final int total;
  final List<ZenTaoProject> projects;

  factory ZenTaoProjectsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['projects'];
    return ZenTaoProjectsResponse(
      total: zentaoInt(json['total']) ?? 0,
      projects: [
        if (raw is List)
          for (final p in raw)
            if (p is Map) ZenTaoProject.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }
}

/// A ZenTao execution (sprint/iteration) from `GET /projects/{id}/executions`.
class ZenTaoExecution {
  const ZenTaoExecution({required this.id, required this.name});

  final String id;
  final String name;

  factory ZenTaoExecution.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = (json['name'] ?? json['title'])?.toString() ?? id;
    return ZenTaoExecution(id: id, name: name);
  }
}

/// `GET /projects/{id}/executions` → `{ total, executions: [...] }`.
class ZenTaoExecutionsResponse {
  const ZenTaoExecutionsResponse({
    required this.total,
    required this.executions,
  });

  final int total;
  final List<ZenTaoExecution> executions;

  factory ZenTaoExecutionsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['executions'];
    return ZenTaoExecutionsResponse(
      total: zentaoInt(json['total']) ?? 0,
      executions: [
        if (raw is List)
          for (final e in raw)
            if (e is Map)
              ZenTaoExecution.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

/// `GET /executions/{id}/tasks` → `{ total, tasks: [...] }`.
class ZenTaoExecutionTasksResponse {
  const ZenTaoExecutionTasksResponse({
    required this.total,
    required this.tasks,
  });

  final int total;
  final List<ZenTaoEntity> tasks;

  factory ZenTaoExecutionTasksResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tasks'];
    return ZenTaoExecutionTasksResponse(
      total: zentaoInt(json['total']) ?? 0,
      tasks: [
        if (raw is List)
          for (final t in raw)
            if (t is Map) ZenTaoEntity.fromJson(Map<String, dynamic>.from(t)),
      ],
    );
  }
}
