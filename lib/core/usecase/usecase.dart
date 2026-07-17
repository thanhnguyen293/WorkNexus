/// Base type for a Clean Architecture interactor. Presentation controllers
/// depend on these, never on repositories directly.
///
/// [Out] is intentionally open so a use case can return a `Future<Result<T>>`
/// (commands) or a `Stream<T>` (reactive reads). [In] is the parameter object
/// ([NoParams] when none are needed).
abstract class UseCase<Out, In> {
  const UseCase();

  Out call(In params);
}

/// Marker for use cases that take no parameters.
class NoParams {
  const NoParams();
}
