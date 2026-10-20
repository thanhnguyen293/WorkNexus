import '../../error/failure.dart';
import '../../error/result.dart';
import '../../usecase/usecase.dart';
import '../entities/workspace.dart';

/// A workspace and the name and badge letters it is to carry.
class WorkspaceRename {
  const WorkspaceRename({
    required this.workspace,
    required this.name,
    required this.shortCode,
  });

  final Workspace workspace;
  final String name;

  /// The letters on the badge; blank takes them from [name].
  final String shortCode;
}

/// Gives a workspace a new name and badge letters. The name is trimmed and
/// must be there (and no longer than [maxNameLength]); the letters are
/// upper-cased, at most [maxCodeLength], and drawn from the name when left
/// blank. The personal workspace keeps its name (it is shown in the app's own
/// words, whatever language) and may only change its letters.
///
/// A refusal is a [ValidationFailure] whose `fields` say what is wrong
/// ([nameField] or [codeField] → [missing] or [tooLong]), so the UI can say it
/// in the user's language.
class RenameWorkspace extends UseCase<Result<Workspace>, WorkspaceRename> {
  const RenameWorkspace();

  static const maxNameLength = 40;
  static const maxCodeLength = 4;

  static const nameField = 'name';
  static const codeField = 'shortCode';
  static const missing = 'missing';
  static const tooLong = 'tooLong';

  @override
  Result<Workspace> call(WorkspaceRename r) {
    final workspace = r.workspace;
    final name = workspace.isPersonal ? workspace.name : r.name.trim();
    if (name.isEmpty) {
      return const Err(
        ValidationFailure('Name is required', fields: {nameField: missing}),
      );
    }
    if (name.length > maxNameLength) {
      return const Err(
        ValidationFailure('Name is too long', fields: {nameField: tooLong}),
      );
    }
    final typed = r.shortCode.trim().toUpperCase();
    if (typed.length > maxCodeLength) {
      return const Err(
        ValidationFailure(
          'Badge letters are too long',
          fields: {codeField: tooLong},
        ),
      );
    }
    return Ok(
      workspace.copyWith(
        name: name,
        shortCode: typed.isEmpty ? shortCodeOf(name) : typed,
      ),
    );
  }

  /// Letters for a badge from a name: the initials of its first three words
  /// ("Company A" → "CA"), or a single word's first letters ("Acme" → "ACM").
  static String shortCodeOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final code = words.length > 1
        ? words.take(3).map((w) => w[0]).join()
        : words.first.substring(0, words.first.length.clamp(0, 3));
    return code.toUpperCase();
  }
}
