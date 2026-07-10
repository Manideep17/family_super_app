import 'package:equatable/equatable.dart';

/// `vault_items/{id}` — shared photos/videos metadata (files in Storage).
class VaultItem extends Equatable {
  const VaultItem({
    required this.id,
    required this.title,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploaderUid,
    required this.uploaderName,
    required this.uploaderEmail,
    required this.personTags,
    this.eventTag,
    required this.createdAt,
    required this.contentType,
    this.extractedText = '',
  });

  final String id;
  final String title;
  final String downloadUrl;
  final String storagePath;
  final String uploaderUid;
  final String uploaderName;
  final String uploaderEmail;
  final List<String> personTags;
  final String? eventTag;
  final DateTime createdAt;
  final String contentType;

  /// On-device OCR text (see `TextExtractionService`) — lets the vault be
  /// searched by what's *in* a photo (a bill, a report card, a note), not
  /// just its title. Empty when OCR found nothing or isn't supported.
  final String extractedText;

  bool get isImage => contentType.startsWith('image/');

  @override
  List<Object?> get props => [
        id,
        title,
        downloadUrl,
        storagePath,
        uploaderUid,
        uploaderName,
        uploaderEmail,
        personTags,
        eventTag,
        createdAt,
        contentType,
        extractedText,
      ];
}
