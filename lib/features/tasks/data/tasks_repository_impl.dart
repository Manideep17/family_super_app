import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/push/free_push_bridge.dart';
import '../../family/data/family_scope.dart';
import '../../family/domain/entities/family_member.dart';
import '../domain/entities/family_task.dart';
import '../domain/repositories/tasks_repository.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl({
    required FamilyScope scope,
    required List<FamilyMember> roster,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _roster = roster,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final List<FamilyMember> _roster;
  final String? _displayName;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _tasks => _scope.tasks;

  User get _user {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  String _name(User u) {
    final memberName = _displayName?.trim();
    if (memberName != null && memberName.isNotEmpty) {
      return memberName;
    }
    final n = u.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return u.email ?? 'Family';
  }

  FamilyMember? _byEmail(String email) {
    final lower = email.trim().toLowerCase();
    for (final m in _roster) {
      if (m.email == lower) return m;
    }
    return null;
  }

  FamilyTask _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime due;
    final dueRaw = d['dueAt'];
    if (dueRaw is Timestamp) {
      due = dueRaw.toDate();
    } else {
      due = DateTime.now();
    }
    DateTime created;
    final cRaw = d['createdAt'];
    if (cRaw is Timestamp) {
      created = cRaw.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return FamilyTask(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      assignerUid: d['assignerUid'] as String? ?? '',
      assignerEmail: (d['assignerEmail'] as String? ?? '').toLowerCase(),
      assignerName: d['assignerName'] as String? ?? '',
      assigneeEmail: (d['assigneeEmail'] as String? ?? '').toLowerCase(),
      assigneeName: d['assigneeName'] as String? ?? '',
      assigneeUid: d['assigneeUid'] as String? ?? '',
      dueAt: due,
      rewardPoints: (d['rewardPoints'] as num?)?.toInt() ?? 0,
      status: TaskStatus.parse(d['status'] as String?),
      createdAt: created,
      submittedNote: d['submittedNote'] as String?,
      rejectedReason: d['rejectedReason'] as String?,
    );
  }

  @override
  Stream<FamilyTask?> watchTask(String taskId) {
    return _tasks.doc(taskId).snapshots().map((s) {
      if (!s.exists) return null;
      return _fromDoc(s);
    });
  }

  @override
  Stream<List<FamilyTask>> watchTasksInvolvingMe() {
    final email = _user.email?.toLowerCase();
    if (email == null) {
      return const Stream.empty();
    }
    return _tasks
        .where('participantEmails', arrayContains: email)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      return list;
    });
  }

  @override
  Future<String> createTask({
    required String title,
    required String description,
    required String assigneeEmail,
    required DateTime dueAt,
    required int rewardPoints,
  }) async {
    final u = _user;
    final assignerEmail = u.email?.toLowerCase();
    if (assignerEmail == null) throw StateError('No email on account');

    final assignee = assigneeEmail.trim().toLowerCase();
    final assigneeMember = _byEmail(assignee);
    if (assigneeMember == null) {
      throw ArgumentError('Pick a member of your family.');
    }

    final participants = <String>{assignerEmail, assignee}.toList()..sort();

    final doc = await _tasks.add({
      'title': title.trim(),
      'description': description.trim(),
      'assignerUid': u.uid,
      'assignerEmail': assignerEmail,
      'assignerName': _name(u),
      'assigneeEmail': assignee,
      'assigneeName': assigneeMember.displayName,
      'dueAt': Timestamp.fromDate(dueAt),
      'rewardPoints': rewardPoints < 0 ? 0 : rewardPoints,
      'status': TaskStatus.pending.wireName,
      'createdAt': FieldValue.serverTimestamp(),
      'participantEmails': participants,
      'assigneeUid': assigneeMember.uid,
    });
    try {
      await FreePushBridge.notifyFamily(
        familyId: _scope.familyId,
        title: 'New task assigned',
        body:
            '${_name(u)} assigned "${title.trim()}" to ${assigneeMember.displayName}',
        route: '/home',
        actorUid: u.uid,
        extraData: {'kind': 'task', 'taskId': doc.id},
      );
    } catch (_) {}
    await AppAnalytics.logEvent(
      'task_created',
      params: {'family_id': _scope.familyId, 'reward_points': rewardPoints},
    );
    return doc.id;
  }

  @override
  Future<void> submitTask(String taskId, {String? note}) async {
    final email = _user.email?.toLowerCase();
    if (email == null) return;
    final snap = await _tasks.doc(taskId).get();
    if (!snap.exists) throw StateError('Task not found');
    final t = _fromDoc(snap);
    if (!t.isAssignee(email)) {
      throw StateError('Only the assignee can submit this task.');
    }
    if (t.status != TaskStatus.pending) {
      throw StateError('Task is not waiting for completion.');
    }
    await _tasks.doc(taskId).update({
      'status': TaskStatus.submitted.wireName,
      'submittedNote': note?.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'assigneeUid': _user.uid,
    });
    try {
      await FreePushBridge.notifyFamily(
        familyId: _scope.familyId,
        title: 'Task submitted',
        body: '${_name(_user)} submitted "${t.title}"',
        route: '/home',
        actorUid: _user.uid,
        extraData: {'kind': 'task', 'taskId': taskId},
      );
    } catch (_) {}
    await AppAnalytics.logEvent(
      'task_submitted',
      params: {'family_id': _scope.familyId},
    );
  }

  @override
  Future<void> approveTask(String taskId) async {
    final email = _user.email?.toLowerCase();
    if (email == null) return;
    final snap = await _tasks.doc(taskId).get();
    if (!snap.exists) throw StateError('Task not found');
    final t = _fromDoc(snap);
    if (!t.isAssigner(email)) {
      throw StateError('Only the assigner can approve.');
    }
    if (t.status != TaskStatus.submitted) {
      throw StateError('Task is not waiting for approval.');
    }
    await _tasks.doc(taskId).update({
      'status': TaskStatus.approved.wireName,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    try {
      await FreePushBridge.notifyFamily(
        familyId: _scope.familyId,
        title: 'Task approved',
        body: '${_name(_user)} approved "${t.title}"',
        route: '/home',
        actorUid: _user.uid,
        extraData: {'kind': 'task', 'taskId': taskId},
      );
    } catch (_) {}
    await AppAnalytics.logEvent(
      'task_approved',
      params: {'family_id': _scope.familyId},
    );
  }

  @override
  Future<void> rejectTask(String taskId, {String? reason}) async {
    final email = _user.email?.toLowerCase();
    if (email == null) return;
    final snap = await _tasks.doc(taskId).get();
    if (!snap.exists) throw StateError('Task not found');
    final t = _fromDoc(snap);
    if (!t.isAssigner(email)) {
      throw StateError('Only the assigner can reject.');
    }
    if (t.status != TaskStatus.submitted) {
      throw StateError('Task is not waiting for approval.');
    }
    await _tasks.doc(taskId).update({
      'status': TaskStatus.rejected.wireName,
      'rejectedReason': reason?.trim(),
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    try {
      await FreePushBridge.notifyFamily(
        familyId: _scope.familyId,
        title: 'Task rejected',
        body: '${_name(_user)} rejected "${t.title}"',
        route: '/home',
        actorUid: _user.uid,
        extraData: {'kind': 'task', 'taskId': taskId},
      );
    } catch (_) {}
    await AppAnalytics.logEvent(
      'task_rejected',
      params: {'family_id': _scope.familyId},
    );
  }
}
