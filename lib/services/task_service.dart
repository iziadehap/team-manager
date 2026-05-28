import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/team_task.dart';
class TaskService {
  TaskService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<TeamTask>> watchTasks(String teamId, {TaskFilter? filter}) {
    return _firestore
        .collection(FirestorePaths.teamTasks(teamId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => TeamTask.fromFirestore(doc, teamId: teamId))
              .toList();
          if (filter == null || filter == TaskFilter.all) return tasks;
          if (filter == TaskFilter.pending) {
            return tasks.where((t) => !t.isDone).toList();
          }
          return tasks.where((t) => t.isDone).toList();
        });
  }

  Stream<TeamTask> watchTask(String teamId, String taskId) {
    return _firestore
        .doc(FirestorePaths.teamTask(teamId, taskId))
        .snapshots()
        .map((doc) => TeamTask.fromFirestore(doc, teamId: teamId));
  }

  Future<TeamTask> createTask({
    required String teamId,
    required String createdBy,
    required String title,
    String? description,
    List<String> assignedTo = const [],
    DateTime? dueDate,
  }) async {
    final taskId = _uuid.v4();
    final assigneeStatus = {
      for (final id in assignedTo) id: 'pending',
    };
    final task = TeamTask(
      id: taskId,
      teamId: teamId,
      title: title.trim(),
      description: description?.trim(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      assignedTo: assignedTo,
      assigneeStatus: assigneeStatus,
    );
    await _firestore
        .doc(FirestorePaths.teamTask(teamId, taskId))
        .set(task.toMap());
    return task;
  }

  Future<void> updateTask(TeamTask task) async {
    await _firestore
        .doc(FirestorePaths.teamTask(task.teamId, task.id))
        .update(task.toMap());
  }

  Future<void> markAssigneeDone({
    required String teamId,
    required String taskId,
    required String userId,
  }) async {
    final ref = _firestore.doc(FirestorePaths.teamTask(teamId, taskId));
    final doc = await ref.get();
    if (!doc.exists) throw AppException('Task not found.');
    final task = TeamTask.fromFirestore(doc, teamId: teamId);
    final status = Map<String, String>.from(task.assigneeStatus);
    status[userId] = 'done';
    await ref.update({'assigneeStatus': status});
  }

  Future<void> deleteTask({
    required String teamId,
    required String taskId,
  }) async {
    await _firestore.doc(FirestorePaths.teamTask(teamId, taskId)).delete();
  }

  Future<Map<String, int>> userTaskStats(String userId) async {
    final userDoc = await _firestore.doc(FirestorePaths.user(userId)).get();
    final teamIds = List<String>.from(
      userDoc.data()?['teams'] as List<dynamic>? ?? [],
    );
    var completed = 0;
    var pending = 0;
    for (final teamId in teamIds) {
      final tasks = await _firestore
          .collection(FirestorePaths.teamTasks(teamId))
          .get();
      for (final doc in tasks.docs) {
        final task = TeamTask.fromFirestore(doc, teamId: teamId);
        if (task.assignedTo.contains(userId) || task.createdBy == userId) {
          if (task.assigneeStatus[userId] == 'done' || task.isDone) {
            completed++;
          } else {
            pending++;
          }
        }
      }
    }
    return {'completed': completed, 'pending': pending};
  }
}
