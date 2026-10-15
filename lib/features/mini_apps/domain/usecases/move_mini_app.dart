import '../../../../core/error/result.dart';
import '../entities/mini_app.dart';
import '../repositories/mini_app_repository.dart';

/// Moves the app at index [from] of [apps] (in rail order) to index [to], and
/// keeps the new order. Resolves to the reordered list, so the rail can show
/// it before the database answers.
class MoveMiniApp {
  const MoveMiniApp(this._repository);

  final MiniAppRepository _repository;

  Future<Result<List<MiniApp>>> call(
    List<MiniApp> apps, {
    required int from,
    required int to,
  }) async {
    final moved = reorder(apps, from: from, to: to);
    if (identical(moved, apps)) return Ok(apps);
    final saved = await _repository.saveOrder([for (final a in moved) a.id]);
    return switch (saved) {
      Ok() => Ok(moved),
      Err(:final failure) => Err(failure),
    };
  }

  /// [apps] with the one at [from] moved to [to] and positions renumbered;
  /// [apps] itself when the move goes nowhere or is out of range.
  static List<MiniApp> reorder(
    List<MiniApp> apps, {
    required int from,
    required int to,
  }) {
    final inRange = from >= 0 && to >= 0 && from < apps.length;
    if (from == to || !inRange || to >= apps.length) return apps;
    final moved = [...apps];
    moved.insert(to, moved.removeAt(from));
    return [for (final (i, a) in moved.indexed) a.copyWith(position: i)];
  }
}
