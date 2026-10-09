part of 'zentao_client.dart';

/// Catalog list endpoints: products and their bugs (REST v1, or the classic
/// browse channel for the tab views), projects, executions and their tasks.
mixin _ZenTaoCatalogReads on _ZenTaoClientBase {
  /// Product list used by the ZenTao Sources tab.
  Future<ZenTaoProductsResponse> products({
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/products',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProductsResponse.fromJson(_responseMap(res.data));
  }

  /// All bugs for a product via REST v1 `GET /products/{id}/bugs`. This endpoint
  /// does **not** honor ZenTao's `browseType` tab views (it ignores the param and
  /// always returns every bug) — use [classicProductBugs] for the tab slices.
  Future<ZenTaoProductBugsResponse> productBugs(
    String productId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/products/$productId/bugs',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProductBugsResponse.fromJson(_responseMap(res.data));
  }

  /// Bugs for a product via the **classic** `bug-browse-…json` action, which —
  /// unlike REST v1 — honors ZenTao's [browseType] tab views (`all` / `unclosed`
  /// / `openedbyme` / `assigntome` / `resolvedbyme` / `assignedbyme`). URL:
  /// `{base}/bug-browse-{productID}-0-{browseType}-0-id_desc-0-{recPerPage}-{pageID}.json`.
  /// The response is the classic `{status, data}` envelope (data is sometimes a
  /// JSON string) whose payload carries `bugs` (a list or an id-keyed map) and a
  /// `pager` with `recTotal`. Parsed leniently; the exact shape is validated live
  /// (capture from the Talker panel, like `products_json.txt`).
  Future<ZenTaoProductBugsResponse> classicProductBugs(
    String productId, {
    required String browseType,
    int recPerPage = kDefaultApiPageLimit,
    int pageID = 1,
  }) async {
    final token = await _ensureToken();
    final path =
        'bug-browse-$productId-0-$browseType-0-id_desc-0-$recPerPage-$pageID';
    final res = await _dio.get<dynamic>(
      '$baseUrl/$path.json',
      queryParameters: {'zentaosid': token},
    );
    Object? data = res.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return const ZenTaoProductBugsResponse(total: 0, bugs: []);
      }
    }
    Object? payload = data is Map ? (data['data'] ?? data) : null;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        payload = null;
      }
    }
    if (payload is! Map) {
      return const ZenTaoProductBugsResponse(total: 0, bugs: []);
    }
    final rawBugs = payload['bugs'];
    final bugs = <ZenTaoEntity>[];
    if (rawBugs is List) {
      for (final b in rawBugs) {
        if (b is Map) {
          bugs.add(ZenTaoEntity.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    } else if (rawBugs is Map) {
      for (final b in rawBugs.values) {
        if (b is Map) {
          bugs.add(ZenTaoEntity.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    }
    final pager = payload['pager'];
    final total = pager is Map
        ? (zentaoInt(pager['recTotal']) ?? bugs.length)
        : bugs.length;
    return ZenTaoProductBugsResponse(total: total, bugs: bugs);
  }

  /// Projects for this account (`GET /projects`), used to group executions.
  Future<ZenTaoProjectsResponse> projects({
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/projects',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProjectsResponse.fromJson(_responseMap(res.data));
  }

  /// Executions of a project (`GET /projects/{id}/executions`).
  Future<ZenTaoExecutionsResponse> projectExecutions(
    String projectId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/projects/$projectId/executions',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoExecutionsResponse.fromJson(_responseMap(res.data));
  }

  /// Tasks of an execution (`GET /executions/{id}/tasks`), used to sync all
  /// tasks regardless of assignee.
  Future<ZenTaoExecutionTasksResponse> executionTasks(
    String executionId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/executions/$executionId/tasks',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoExecutionTasksResponse.fromJson(_responseMap(res.data));
  }
}
