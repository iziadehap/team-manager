import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/task_comment.dart';

class CommentService {
  CommentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<TaskComment>> watchComments(String teamId, String taskId) {
    return _firestore
        .collection(FirestorePaths.taskComments(teamId, taskId))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(TaskComment.fromFirestore).toList(),
        );
  }

  Future<void> addComment({
    required String teamId,
    required String taskId,
    required String userId,
    required String text,
  }) async {
    final id = _uuid.v4();
    final comment = TaskComment(
      id: id,
      text: text.trim(),
      userId: userId,
      createdAt: DateTime.now(),
    );
    await _firestore
        .doc('${FirestorePaths.taskComments(teamId, taskId)}/$id')
        .set(comment.toMap());
  }
}
