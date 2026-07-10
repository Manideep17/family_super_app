import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Client-only hides (per device) so reporters can soften their own feed
/// without server deletes.
class LocalHideStore {
  LocalHideStore._();

  static String _chatKey(String familyId) => 'local_hide_chat_v1_$familyId';
  static String _diaryKey(String familyId) => 'local_hide_diary_v1_$familyId';

  static Future<Set<String>> hiddenChatMessageIds(String familyId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_chatKey(familyId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> hiddenDiaryStoryIds(String familyId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_diaryKey(familyId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> hideChatMessage(String familyId, String messageId) async {
    final p = await SharedPreferences.getInstance();
    final cur = await hiddenChatMessageIds(familyId);
    cur.add(messageId);
    await p.setString(_chatKey(familyId), jsonEncode(cur.toList()));
  }

  static Future<void> hideDiaryStory(String familyId, String storyId) async {
    final p = await SharedPreferences.getInstance();
    final cur = await hiddenDiaryStoryIds(familyId);
    cur.add(storyId);
    await p.setString(_diaryKey(familyId), jsonEncode(cur.toList()));
  }

  static Future<void> unhideChatMessage(String familyId, String messageId) async {
    final p = await SharedPreferences.getInstance();
    final cur = await hiddenChatMessageIds(familyId);
    cur.remove(messageId);
    await p.setString(_chatKey(familyId), jsonEncode(cur.toList()));
  }

  static Future<void> clearAllChatHides(String familyId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_chatKey(familyId));
  }

  static Future<void> clearAllDiaryHides(String familyId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_diaryKey(familyId));
  }
}
