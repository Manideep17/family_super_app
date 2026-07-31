import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_flags.dart' show AppFlags;

class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.storagePath,
    required this.contentType,
  });

  final String url;
  final String storagePath;
  final String contentType;
}

abstract class MediaUploadService {
  /// [familyId] is required so the object lands under
  /// `families/{familyId}/{folder}/{ownerUid}/...` — the exact path shape
  /// `storage.rules` checks against (member-of-family read, own-uid write).
  Future<UploadedMedia> uploadFile({
    required String familyId,
    required File file,
    required String folder,
    required String ownerUid,
    required String fileName,
    required String contentType,
  });
}

/// Uploads straight to this project's Firebase Storage bucket (Blaze plan
/// required — Storage has no Spark/free tier). Security is enforced by
/// `storage.rules`: only members of the family may read, and only the
/// uploading uid may write to their own `{folder}/{uid}/...` path — a
/// meaningfully tighter model than an unsigned Cloudinary preset, which lets
/// anyone who discovers the preset name upload to the account regardless of
/// whether they're even signed into the app.
class FirebaseStorageMediaUploadService implements MediaUploadService {
  FirebaseStorageMediaUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<UploadedMedia> uploadFile({
    required String familyId,
    required File file,
    required String folder,
    required String ownerUid,
    required String fileName,
    required String contentType,
  }) async {
    if (!AppFlags.mediaUploadsEnabled) {
      throw StateError('Media uploads are disabled in this build.');
    }
    if (familyId.isEmpty) {
      throw StateError('No family — cannot upload.');
    }
    final ext = _extensionFor(file.path, contentType);
    final path = 'families/$familyId/$folder/$ownerUid/$fileName$ext';
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return UploadedMedia(url: url, storagePath: path, contentType: contentType);
  }

  String _extensionFor(String originalPath, String contentType) {
    final dot = originalPath.lastIndexOf('.');
    if (dot != -1 && dot < originalPath.length - 1) {
      return originalPath.substring(dot);
    }
    if (contentType.startsWith('video/')) return '.mp4';
    if (contentType.startsWith('audio/')) return '.m4a';
    return '.jpg';
  }
}
