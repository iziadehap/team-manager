import 'package:cloud_firestore/cloud_firestore.dart';

class TaskComment {
  const TaskComment({
    required this.id,
    required this.text,
    required this.userId,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String userId;
  final DateTime createdAt;

  factory TaskComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TaskComment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
