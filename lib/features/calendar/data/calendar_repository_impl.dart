import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../family/data/family_scope.dart';
import '../domain/entities/calendar_event.dart';
import '../domain/repositories/calendar_repository.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({
    required FamilyScope scope,
    required Set<String> familyMemberEmails,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _familyEmails = familyMemberEmails,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final Set<String> _familyEmails;
  final String? _displayName;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _events =>
      _scope.calendarEvents;

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

  CalendarEvent _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final start = d['startAt'];
    DateTime startAt;
    if (start is Timestamp) {
      startAt = start.toDate();
    } else {
      startAt = DateTime.now();
    }
    DateTime? endAt;
    final end = d['endAt'];
    if (end is Timestamp) endAt = end.toDate();

    final parts = (d['participantEmails'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const <String>[];

    return CalendarEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      startAt: startAt,
      endAt: endAt,
      allDay: d['allDay'] as bool? ?? false,
      eventType: d['eventType'] as String? ?? 'other',
      creatorUid: d['creatorUid'] as String? ?? '',
      creatorName: d['creatorName'] as String? ?? '',
      creatorEmail: (d['creatorEmail'] as String? ?? '').toLowerCase(),
      participantEmails: parts,
    );
  }

  @override
  Stream<CalendarEvent?> watchEvent(String eventId) {
    return _events.doc(eventId).snapshots().map((s) {
      if (!s.exists) return null;
      return _fromDoc(s);
    });
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({int limit = 400}) {
    return _events
        .orderBy('startAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime startAt,
    DateTime? endAt,
    required bool allDay,
    required String eventType,
    required List<String> participantEmails,
  }) async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) throw StateError('No email');
    final lower = participantEmails
        .map((e) => e.trim().toLowerCase())
        .toSet();
    final parts = _familyEmails.isEmpty
        ? lower.toList()
        : lower.where(_familyEmails.contains).toList();
    final participants = <String>{email, ...parts}.toList()..sort();

    final doc = await _events.add({
      'title': title.trim(),
      'description': description.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt != null ? Timestamp.fromDate(endAt) : null,
      'allDay': allDay,
      'eventType': eventType,
      'creatorUid': u.uid,
      'creatorName': _name(u),
      'creatorEmail': email,
      'participantEmails': participants,
    });
    return doc.id;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final snap = await _events.doc(eventId).get();
    if (!snap.exists) return;
    final t = _fromDoc(snap);
    final me = _user.email?.toLowerCase();
    if (me == null || t.creatorEmail != me) {
      throw StateError('Only the creator can delete this event.');
    }
    await _events.doc(eventId).delete();
  }
}
