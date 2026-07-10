import 'dart:io';

import '../entities/vault_item.dart';

abstract class VaultRepository {
  Stream<List<VaultItem>> watchItems({int limit});

  Future<void> uploadPhoto({
    required File file,
    required String title,
    required List<String> personTags,
    String? eventTag,
    /// On-device OCR text, pre-extracted by the caller (see
    /// `TextExtractionService`) so the repository stays free of ML Kit
    /// concerns — it just persists whatever text was found, if any.
    String? extractedText,
  });

  Future<void> deleteItem(String itemId);
}
