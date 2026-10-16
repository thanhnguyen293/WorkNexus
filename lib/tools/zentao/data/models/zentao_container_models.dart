/// DTOs for the containers ZenTao files work under — products, projects and
/// their programs — as its REST v1 API sends them.
library;

import 'zentao_models.dart' show zentaoInt;

/// A ZenTao product from `GET /products`.
class ZenTaoProduct {
  const ZenTaoProduct({
    required this.id,
    required this.name,
    this.programId,
    this.programName,
    this.lineId,
    this.lineName,
  });

  final String id;
  final String name;

  /// The program and product line ZenTao files the product under, when the
  /// reply was its merged tree (see [ZenTaoProductsResponse]).
  final String? programId;
  final String? programName;
  final String? lineId;
  final String? lineName;

  factory ZenTaoProduct.fromJson(
    Map<String, dynamic> json, {
    ZenTaoProductNode? program,
    ZenTaoProductNode? line,
  }) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? id;
    return ZenTaoProduct(
      id: id,
      name: name,
      programId: program?.id,
      programName: program?.name,
      lineId: line?.id,
      lineName: line?.name,
    );
  }
}

/// A program or product-line node of ZenTao's product tree: id and name.
typedef ZenTaoProductNode = ({String id, String name});

/// `GET /products` → `{ total, products: [...] }`. With `mergeChildren=1`
/// the list is ZenTao's tree instead (`api/v1/entries/products.php`): program
/// nodes (`type: "program"`) holding products and product-line nodes
/// (`type: "line"`), line nodes holding products, and products with no
/// program at the top, bare or in a top-level line. A product has a `type` of
/// its own (`normal` / `branch` / `platform`), so only `program` and `line`
/// mark a node; anything else is a product. Read in ZenTao's order, flat,
/// each product carrying its program and line.
class ZenTaoProductsResponse {
  const ZenTaoProductsResponse({required this.total, required this.products});

  final int total;
  final List<ZenTaoProduct> products;

  factory ZenTaoProductsResponse.fromJson(Map<String, dynamic> json) {
    final products = <ZenTaoProduct>[];
    void walk(
      Object? nodes, {
      ZenTaoProductNode? program,
      ZenTaoProductNode? line,
    }) {
      // PHP may send a keyed array (a JSON object) where a list is meant.
      final list = switch (nodes) {
        final List<dynamic> l => l,
        final Map<dynamic, dynamic> m => m.values.toList(),
        _ => const <dynamic>[],
      };
      for (final raw in list) {
        if (raw is! Map) continue;
        final node = Map<String, dynamic>.from(raw);
        final kind = node['type']?.toString();
        final self = (
          id: node['id']?.toString() ?? '',
          name: node['name']?.toString() ?? '',
        );
        if (kind == 'program') {
          // A sub-program files its products under itself.
          walk(node['children'], program: self);
        } else if (kind == 'line') {
          walk(node['children'], program: program, line: self);
        } else {
          products.add(
            ZenTaoProduct.fromJson(node, program: program, line: line),
          );
        }
      }
    }

    walk(json['products']);
    return ZenTaoProductsResponse(
      total: zentaoInt(json['total']) ?? 0,
      products: products,
    );
  }
}

/// A ZenTao project from `GET /projects`. Projects group executions, which in
/// turn hold tasks (parallel to how products hold bugs).
class ZenTaoProject {
  const ZenTaoProject({
    required this.id,
    required this.name,
    this.programId,
    this.programName,
  });

  final String id;
  final String name;
  final String? programId;
  final String? programName;

  /// A project's program is its `parent` (a `zt_project` row: `GET
  /// /projects` sends the rows as they are); `program` where a server sends
  /// one. The name comes from `/programs` (see [ZenTaoProgramsResponse]) unless
  /// the row carries `programName`.
  factory ZenTaoProject.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = (json['name'] ?? json['title'])?.toString() ?? id;
    String? idOf(Object? raw) {
      final v = raw?.toString().trim();
      return v == null || v.isEmpty || v == '0' ? null : v;
    }

    return ZenTaoProject(
      id: id,
      name: name,
      programId: idOf(json['parent']) ?? idOf(json['program']),
      programName: switch (json['programName']?.toString().trim()) {
        final n? when n.isNotEmpty => n,
        _ => null,
      },
    );
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

/// `GET /programs` → the account's programs, read leniently: a `programs`
/// list (or id-keyed object) of `{id, name, children?}`, sub-programs in
/// `children` included. Only the names are used, to label a project's
/// program.
class ZenTaoProgramsResponse {
  const ZenTaoProgramsResponse({required this.total, required this.names});

  final int total;

  /// Program names by id, in ZenTao's order.
  final Map<String, String> names;

  factory ZenTaoProgramsResponse.fromJson(Map<String, dynamic> json) {
    final names = <String, String>{};
    void walk(Object? nodes) {
      final list = switch (nodes) {
        final List<dynamic> l => l,
        final Map<dynamic, dynamic> m => m.values.toList(),
        _ => const <dynamic>[],
      };
      for (final raw in list) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        final name = raw['name']?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) names.putIfAbsent(id, () => name);
        walk(raw['children']);
      }
    }

    walk(json['programs']);
    return ZenTaoProgramsResponse(
      total: zentaoInt(json['total']) ?? 0,
      names: names,
    );
  }
}
