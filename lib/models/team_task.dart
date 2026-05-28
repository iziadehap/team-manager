import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskFilter { all, pending, done }

class TeamTask {
  const TeamTask({
    required this.id,
    required this.teamId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.dueDate,
    this.assignedTo = const [],
    this.assigneeStatus = const {},
  });

  final String id;
  final String teamId;
  final String title;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<String> assignedTo;
  final Map<String, String> assigneeStatus;

  bool get isDone {
    if (assignedTo.isEmpty) {
      return assigneeStatus.values.every((s) => s == 'done');
    }
    return assignedTo.every((id) => assigneeStatus[id] == 'done');
  }

  int get pendingAssigneeCount {
    if (assignedTo.isEmpty) return isDone ? 0 : 1;
    return assignedTo
        .where((id) => assigneeStatus[id] != 'done')
        .length;
  }

  factory TeamTask.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String teamId,
  }) {
    final data = doc.data()!;
    final statusRaw = data['assigneeStatus'] as Map<String, dynamic>? ?? {};
    return TeamTask(
      id: doc.id,
      teamId: teamId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      assignedTo: List<String>.from(data['assignedTo'] as List<dynamic>? ?? []),
      assigneeStatus: statusRaw.map(
        (key, value) => MapEntry(key, value as String),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'assignedTo': assignedTo,
      'assigneeStatus': assigneeStatus,
    };
  }

  TeamTask copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedTo,
    Map<String, String>? assigneeStatus,
  }) {
    return TeamTask(
      id: id,
      teamId: teamId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      assignedTo: assignedTo ?? this.assignedTo,
      assigneeStatus: assigneeStatus ?? this.assigneeStatus,
    );
  }
}
