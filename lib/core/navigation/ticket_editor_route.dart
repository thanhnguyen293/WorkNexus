import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which ZenTao bug or task the full-screen editor is open on.
sealed class TicketEditorRoute {
  const TicketEditorRoute({required this.accountId});

  final String accountId;

  /// What tells two routes apart (the editor's state is kept per route).
  List<Object> get _key;

  @override
  bool operator ==(Object other) =>
      other is TicketEditorRoute &&
      other.runtimeType == runtimeType &&
      other.accountId == accountId &&
      _key.indexed.every((e) => other._key[e.$1] == e.$2);

  @override
  int get hashCode => Object.hash(runtimeType, accountId, Object.hashAll(_key));
}

/// A new bug in product [productId].
class NewBugRoute extends TicketEditorRoute {
  const NewBugRoute({required super.accountId, required this.productId});

  final String productId;

  @override
  List<Object> get _key => [productId];
}

/// A new task in execution [executionId].
class NewTaskRoute extends TicketEditorRoute {
  const NewTaskRoute({required super.accountId, required this.executionId});

  final String executionId;

  @override
  List<Object> get _key => [executionId];
}

/// Bug [bugId] (its ZenTao id), as edited.
class EditBugRoute extends TicketEditorRoute {
  const EditBugRoute({
    required super.accountId,
    required this.bugId,
    required this.ticketId,
  });

  final String bugId;

  @override
  List<Object> get _key => [bugId];

  /// The bug's WorkNexus ticket, reopened once it is saved.
  final String ticketId;
}

/// Task [taskId] (its ZenTao id), as edited.
class EditTaskRoute extends TicketEditorRoute {
  const EditTaskRoute({
    required super.accountId,
    required this.taskId,
    required this.ticketId,
  });

  final String taskId;

  @override
  List<Object> get _key => [taskId];

  /// The task's WorkNexus ticket, reopened once it is saved.
  final String ticketId;
}

/// The open bug / task editor, which replaces the board and sidebar; null when
/// none is open.
class TicketEditorController extends Notifier<TicketEditorRoute?> {
  @override
  TicketEditorRoute? build() => null;

  void open(TicketEditorRoute route) => state = route;
  void close() => state = null;
}

final ticketEditorProvider =
    NotifierProvider<TicketEditorController, TicketEditorRoute?>(
      TicketEditorController.new,
    );
