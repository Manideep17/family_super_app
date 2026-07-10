import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/push/free_push_bridge.dart';
import '../../family/data/family_scope.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/family_chat_meta.dart';
import '../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required FamilyScope scope,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final String? _displayName;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _chatDoc => _scope.chatDoc();

  CollectionReference<Map<String, dynamic>> get _messages =>
      _scope.chatMessages();

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

  @override
  Stream<List<ChatMessage>> watchMessages({int limit = 120}) {
    return _messages
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_messageFromDoc).toList().reversed.toList(),
        );
  }

  ChatMessage _messageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final typeStr = d['type'] as String? ?? 'text';
    final type = typeStr == 'voice' ? ChatMessageType.voice : ChatMessageType.text;
    final rawReactions = d['reactions'];
    final reactions = Map<String, String>.from(
      (rawReactions is Map ? rawReactions : const {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    return ChatMessage(
      id: doc.id,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      createdAt: created,
      type: type,
      audioUrl: d['audioUrl'] as String?,
      reactions: reactions,
    );
  }

  @override
  Stream<FamilyChatMeta> watchChatMeta() {
    return _chatDoc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return const FamilyChatMeta();
      }
      final d = snap.data()!;
      final membersRaw = d['members'];
      final members = <String, String>{};
      if (membersRaw is Map) {
        membersRaw.forEach((uid, v) {
          if (v is Map && v['name'] != null) {
            members[uid.toString()] = v['name'].toString();
          }
        });
      }
      final readRaw = d['readThrough'];
      final readThrough = <String, DateTime>{};
      if (readRaw is Map) {
        readRaw.forEach((uid, v) {
          if (v is Timestamp) {
            readThrough[uid.toString()] = v.toDate();
          }
        });
      }
      return FamilyChatMeta(members: members, readThrough: readThrough);
    });
  }

  @override
  Future<void> registerCurrentMember() async {
    final u = _user;
    final name = _name(u);
    await _chatDoc.set(
      {
        'members': {
          u.uid: {
            'email': u.email,
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final u = _user;
    final authorName = _name(u);
    await _messages.add({
      'text': trimmed,
      'authorUid': u.uid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'text',
      'reactions': <String, String>{},
    });
    await AppAnalytics.logEvent(
      'chat_message_sent',
      params: {'family_id': _scope.familyId},
    );
    try {
      await FreePushBridge.notifyFamily(
        familyId: _scope.familyId,
        title: 'New family message',
        body: '$authorName: $trimmed',
        route: '/home',
        actorUid: u.uid,
        extraData: {'kind': 'chat'},
      );
    } catch (_) {}
  }

  @override
  Future<void> updateMyReadThrough(DateTime through) async {
    final uid = _user.uid;
    await _chatDoc.set(
      {
        'readThrough': {uid: Timestamp.fromDate(through)},
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> reportMessage({
    required String messageId,
    required String messageAuthorUid,
    required String preview,
  }) async {
    final u = _user;
    await _messages.doc(messageId).collection('reports').doc(u.uid).set({
      'reporterUid': u.uid,
      'familyId': _scope.familyId,
      'kind': 'chat',
      'targetAuthorUid': messageAuthorUid,
      'messageAuthorUid': messageAuthorUid,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setReaction({
    required String messageId,
    String? emoji,
  }) async {
    final uid = _user.uid;
    final ref = _messages.doc(messageId);
    await _scope.firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final raw = data['reactions'];
      final reactions = Map<String, String>.from(
        (raw is Map ? raw : const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      if (emoji == null) {
        reactions.remove(uid);
      } else if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }
}
