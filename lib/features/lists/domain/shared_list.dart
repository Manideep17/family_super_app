import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SharedListKind { grocery, todo, other }

SharedListKind sharedListKindFromString(String? raw) {
  switch (raw) {
    case 'grocery':
      return SharedListKind.grocery;
    case 'todo':
      return SharedListKind.todo;
    default:
      return SharedListKind.other;
  }
}

extension SharedListKindLabel on SharedListKind {
  String get wireValue {
    switch (this) {
      case SharedListKind.grocery:
        return 'grocery';
      case SharedListKind.todo:
        return 'todo';
      case SharedListKind.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case SharedListKind.grocery:
        return 'Grocery';
      case SharedListKind.todo:
        return 'To-do';
      case SharedListKind.other:
        return 'List';
    }
  }
}

/// `families/{fid}/lists/{listId}` — a shared checklist (grocery, to-do,
/// packing list, etc.) any family member can add to and check off.
class SharedList extends Equatable {
  const SharedList({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdBy,
    required this.createdAt,
    this.archived = false,
  });

  final String id;
  final String name;
  final SharedListKind kind;
  final String createdBy;
  final DateTime createdAt;
  final bool archived;

  static SharedList fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    return SharedList(
      id: doc.id,
      name: (d['name'] as String? ?? 'List').trim(),
      kind: sharedListKindFromString(d['kind'] as String?),
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      archived: d['archived'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, kind, createdBy, createdAt, archived];
}
