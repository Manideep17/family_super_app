import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// `families/{fid}/lists/{listId}/items/{itemId}`.
class SharedListItem extends Equatable {
  const SharedListItem({
    required this.id,
    required this.text,
    required this.checked,
    required this.createdBy,
    required this.createdAt,
    this.checkedBy,
    this.checkedAt,
  });

  final String id;
  final String text;
  final bool checked;
  final String createdBy;
  final DateTime createdAt;
  final String? checkedBy;
  final DateTime? checkedAt;

  static SharedListItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    final checkedTs = d['checkedAt'];
    return SharedListItem(
      id: doc.id,
      text: (d['text'] as String? ?? '').trim(),
      checked: d['checked'] == true,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      checkedBy: d['checkedBy'] as String?,
      checkedAt: checkedTs is Timestamp ? checkedTs.toDate() : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, text, checked, createdBy, createdAt, checkedBy, checkedAt];
}
