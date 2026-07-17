/// Domain-level error type. Data-layer exceptions are mapped to one of these so
/// the application/presentation layers never depend on transport specifics.
sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// Network/transport problem (timeouts, connection refused, 5xx).
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// Authentication/authorization problem (bad token, 401/403, expired session).
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

/// The requested entity does not exist (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause});
}

/// A response could not be parsed/normalized into the unified model.
class ParseFailure extends Failure {
  const ParseFailure(super.message, {super.cause});
}

/// A coding-agent or translation process failed.
class AgentFailure extends Failure {
  const AgentFailure(super.message, {super.cause});
}

/// Local persistence (drift/keychain) problem.
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

/// Anything not otherwise classified.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}
