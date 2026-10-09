import 'dart:typed_data';

import '../../error/result.dart';
import '../entities/zentao_ticket_form.dart';

/// Creates and edits ZenTao bugs and tasks through ZenTao's own web forms.
abstract interface class ZenTaoTicketEditor {
  /// A new bug's form in product [productId] (`'0'`: the one ZenTao has
  /// current): a copy of bug [copyOf], or filed against execution
  /// [executionId] and task [taskId], when given.
  Future<Result<BugForm>> newBugForm(
    String accountId,
    String productId, {
    String? copyOf,
    String? executionId,
    String? taskId,
  });

  /// Bug [bugId]'s form, filled in with the bug.
  Future<Result<BugForm>> editBugForm(String accountId, String bugId);

  /// The bug form's choices for a product, project and execution — reloaded
  /// when one of them changes.
  Future<Result<BugFormOptions>> bugOptions(
    String accountId, {
    required String productId,
    String projectId = '0',
    String executionId = '0',
  });

  /// Saves [draft] (a new bug when its id is null), with [form] as loaded;
  /// returns the bug's WorkNexus ticket id. [uid] ties in the images uploaded
  /// into the steps.
  Future<Result<String>> saveBug(
    String accountId,
    BugForm form,
    BugDraft draft, {
    required String uid,
  });

  /// A new task's form in execution [executionId] (`'0'`: the one ZenTao has
  /// current); a subtask of task [parentId] when given.
  Future<Result<TaskForm>> newTaskForm(
    String accountId,
    String executionId, {
    String? parentId,
  });

  /// Task [taskId]'s form, filled in with the task.
  Future<Result<TaskForm>> editTaskForm(String accountId, String taskId);

  /// The task form's choices for an execution — reloaded when it changes.
  Future<Result<TaskFormOptions>> taskOptions(
    String accountId,
    String executionId,
  );

  /// Saves [draft] (a new task when its id is null); returns the task's
  /// WorkNexus ticket id — a new subtask's parent's when ZenTao does not say
  /// which id the subtask got.
  Future<Result<String>> saveTask(
    String accountId,
    TaskForm form,
    TaskDraft draft, {
    required String uid,
  });

  /// An image in a description (behind ZenTao's sign-in), or null.
  Future<Uint8List?> loadImage(String accountId, String url);

  /// Uploads an image put into a description; returns the URL to embed it at.
  Future<Result<String>> uploadImage(
    String accountId,
    String uid,
    Uint8List bytes,
    String fileName,
  );
}
