import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../family/data/family_scope.dart';
import '../domain/shared_list.dart';
import '../domain/shared_list_item.dart';

class ListsRepository {
  ListsRepository({
    required FamilyScope scope,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final FirebaseAuth _auth;

  Stream<List<SharedList>> watchLists({bool includeArchived = false}) {
    return _scope.lists.orderBy('createdAt', descending: true).snapshots().map(
      (s) {
        final all = s.docs.map(SharedList.fromDoc).toList();
        if (includeArchived) return all;
        return all.where((l) => !l.archived).toList();
      },
    );
  }

  Stream<SharedList?> watchList(String listId) {
    return _scope.lists.doc(listId).snapshots().map(
          (s) => s.exists ? SharedList.fromDoc(s) : null,
        );
  }

  Stream<List<SharedListItem>> watchItems(String listId) {
    return _scope.lists
        .doc(listId)
        .collection('items')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(SharedListItem.fromDoc).toList());
  }

  Future<String> createList({
    required String name,
    required SharedListKind kind,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Give the list a name.');
    final ref = await _scope.lists.add({
      'name': trimmed,
      'kind': kind.wireValue,
      'createdBy': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'archived': false,
    });
    AppAnalytics.logEvent('shared_list_created', params: {'kind': kind.wireValue});
    return ref.id;
  }

  Future<void> renameList(String listId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _scope.lists.doc(listId).update({
      'name': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setArchived(String listId, bool archived) async {
    await _scope.lists.doc(listId).update({
      'archived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteList(String listId) async {
    final items = await _scope.lists.doc(listId).collection('items').get();
    final batch = _scope.firestore.batch();
    for (final d in items.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_scope.lists.doc(listId));
    await batch.commit();
  }

  Future<void> addItem(String listId, String text) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _scope.lists.doc(listId).collection('items').add({
      'text': trimmed,
      'checked': false,
      'createdBy': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    AppAnalytics.logEvent('shared_list_item_added');
  }

  Future<void> setChecked(String listId, String itemId, bool checked) async {
    final u = _auth.currentUser;
    await _scope.lists.doc(listId).collection('items').doc(itemId).update({
      'checked': checked,
      'checkedBy': checked ? u?.uid : null,
      'checkedAt': checked ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> deleteItem(String listId, String itemId) async {
    await _scope.lists.doc(listId).collection('items').doc(itemId).delete();
  }

  /// Clears every checked item off the list in one batch — the common
  /// "done shopping, reset for next week" action.
  Future<void> clearChecked(String listId) async {
    final checked = await _scope.lists
        .doc(listId)
        .collection('items')
        .where('checked', isEqualTo: true)
        .get();
    if (checked.docs.isEmpty) return;
    final batch = _scope.firestore.batch();
    for (final d in checked.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
