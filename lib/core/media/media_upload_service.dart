import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_flags.dart';
import '../network/retry.dart';
import '../network/sync_health.dart';

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
  Future<UploadedMedia> uploadFile({
    required File file,
    required String folder,
    required String ownerUid,
    required String fileName,
    required String contentType,
  });
}

class CloudinaryMediaUploadService implements MediaUploadService {
  CloudinaryMediaUploadService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<UploadedMedia> uploadFile({
    required File file,
    required String folder,
    required String ownerUid,
    required String fileName,
    required String contentType,
  }) async {
    if (!AppFlags.mediaUploadsEnabled) {
      throw StateError('Media uploads are disabled in this build.');
    }
    if (!AppFlags.cloudinaryConfigured) {
      throw StateError(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
      );
    }
    const cloud = AppFlags.cloudinaryCloudName;
    const preset = AppFlags.cloudinaryUploadPreset;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/auto/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = '$folder/$ownerUid'
      ..fields['public_id'] = fileName
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var ok = false;
    try {
      final uploaded = await withRetry(
        () async {
          final streamed = await _client.send(request);
          final body = await streamed.stream.bytesToString();
          if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
            throw StateError('Cloud upload failed (${streamed.statusCode}): $body');
          }
          final data = jsonDecode(body) as Map<String, dynamic>;
          final secureUrl = data['secure_url']?.toString() ?? '';
          final publicId = data['public_id']?.toString() ?? '';
          if (secureUrl.isEmpty || publicId.isEmpty) {
            throw StateError('Cloud upload returned incomplete payload.');
          }
          final returnedType = data['resource_type']?.toString() == 'video'
              ? 'video/mp4'
              : contentType;
          return UploadedMedia(
            url: secureUrl,
            storagePath: publicId,
            contentType: returnedType,
          );
        },
        timeout: const Duration(seconds: 20),
      );
      ok = true;
      return uploaded;
    } catch (e) {
      SyncHealth.recordError(e);
      rethrow;
    } finally {
      if (ok) {
        SyncHealth.recordSuccess('Upload synced');
      }
    }
  }
}
