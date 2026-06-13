part of 'main.dart';

// --- DATA MODEL ---

class TaskItem {
  int id;
  String description;
  List<String> boards;
  int priority;
  bool isStarred;
  bool isComplete;
  bool inProgress;
  bool isTask;
  String dateString;
  int timestamp;
  String? dueDate;
  int? parentId;

  TaskItem({
    required this.id,
    required this.description,
    required this.boards,
    this.priority = 1,
    this.isStarred = false,
    this.isComplete = false,
    this.inProgress = false,
    required this.isTask,
    required this.dateString,
    required this.timestamp,
    this.dueDate,
    this.parentId,
  });

  TaskItem copyWith({int? newId}) {
    return TaskItem(
      id: newId ?? id,
      description: description,
      boards: List.from(boards),
      priority: priority,
      isStarred: isStarred,
      isComplete: isComplete,
      inProgress: inProgress,
      isTask: isTask,
      dateString: dateString,
      timestamp: timestamp,
      dueDate: dueDate,
      parentId: parentId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'boards': boards,
    'priority': priority,
    'isStarred': isStarred,
    'isComplete': isComplete,
    'inProgress': inProgress,
    'isTask': isTask,
    'dateString': dateString,
    'timestamp': timestamp,
    'dueDate': dueDate,
    'parentId': parentId,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'],
    description: json['description'],
    boards: List<String>.from(json['boards'] ?? []),
    priority: json['priority'] ?? 1,
    isStarred: json['isStarred'] ?? false,
    isComplete: json['isComplete'] ?? false,
    inProgress: json['inProgress'] ?? false,
    isTask: json['isTask'] ?? true,
    dateString: json['dateString'],
    timestamp: json['timestamp'],
    dueDate: json['dueDate'],
    parentId: json['parentId'],
  );
}
