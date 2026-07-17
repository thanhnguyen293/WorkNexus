/// Lifecycle of a ticket's Vietnamese translation cache entry.
///
/// - [none]     never translated
/// - [loading]  a translation request is in flight
/// - [done]     cached translation matches the current source content hash
/// - [outdated] a cached translation exists but the source changed since
/// - [error]    the last attempt failed
enum TranslationState { none, loading, done, outdated, error }
