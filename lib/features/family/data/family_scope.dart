import 'package:cloud_firestore/cloud_firestore.dart';

/// Tiny helper: every per-family Firestore path in the app goes through this
/// so we can never accidentally hit a root collection. A repository takes
/// a [FamilyScope] (or reads it from a provider) and uses [col] / [doc] to
/// talk to Firestore.
class FamilyScope {
  const FamilyScope({required this.familyId, required this.firestore});

  final String familyId;
  final FirebaseFirestore firestore;

  DocumentReference<Map<String, dynamic>> get familyDoc =>
      firestore.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> col(String name) =>
      familyDoc.collection(name);

  CollectionReference<Map<String, dynamic>> get members => col('members');
  CollectionReference<Map<String, dynamic>> get stories => col('stories');
  CollectionReference<Map<String, dynamic>> get tasks => col('tasks');
  CollectionReference<Map<String, dynamic>> get calendarEvents =>
      col('calendar_events');
  CollectionReference<Map<String, dynamic>> get vaultItems => col('vault_items');
  CollectionReference<Map<String, dynamic>> get memberStats =>
      col('member_stats');
  CollectionReference<Map<String, dynamic>> get gamification =>
      col('gamification');
  CollectionReference<Map<String, dynamic>> get predictions =>
      col('predictions');
  CollectionReference<Map<String, dynamic>> get futurePredictions =>
      col('future_predictions');
  CollectionReference<Map<String, dynamic>> get reels => col('reels');
  CollectionReference<Map<String, dynamic>> get bestMoments =>
      col('best_moments');
  CollectionReference<Map<String, dynamic>> get aiQuizzes => col('ai_quizzes');
  CollectionReference<Map<String, dynamic>> get creativeSubmissions =>
      col('creative_submissions');
  CollectionReference<Map<String, dynamic>> get timeTravelEntries =>
      col('time_travel_entries');
  CollectionReference<Map<String, dynamic>> get polls => col('polls');

  DocumentReference<Map<String, dynamic>> chatDoc({String chatId = 'main'}) =>
      col('chats').doc(chatId);

  CollectionReference<Map<String, dynamic>> chatMessages({
    String chatId = 'main',
  }) =>
      chatDoc(chatId: chatId).collection('messages');

  /// Storage prefix scoped to this family. Mirrors the rules in
  /// `storage.rules` (`families/{fid}/{kind}/{uid}/...`).
  String storagePath(String kind, String uid, String fileName) =>
      'families/$familyId/$kind/$uid/$fileName';
}
