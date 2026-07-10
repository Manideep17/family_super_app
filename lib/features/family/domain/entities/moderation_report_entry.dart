import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the family owner's reports inbox (`collectionGroup('reports')`).
class ModerationReportEntry extends Equatable {
  const ModerationReportEntry({
    required this.firestorePath,
    required this.reporterUid,
    required this.kind,
    required this.preview,
    required this.targetAuthorUid,
    this.createdAt,
  });

  final String firestorePath;
  final String reporterUid;
  /// `chat` or `diary` when written by current clients; older docs may be empty.
  final String kind;
  final String preview;
  final String targetAuthorUid;
  final DateTime? createdAt;

  static ModerationReportEntry fromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final data = d.data() ?? {};
    final ts = data['createdAt'];
    DateTime? at;
    if (ts is Timestamp) at = ts.toDate();

    final target = (data['targetAuthorUid'] as String?) ??
        (data['messageAuthorUid'] as String?) ??
        (data['storyAuthorUid'] as String?) ??
        '';

    return ModerationReportEntry(
      firestorePath: d.reference.path,
      reporterUid: d.id,
      kind: (data['kind'] as String?) ?? '',
      preview: (data['preview'] as String?) ?? '',
      targetAuthorUid: target,
      createdAt: at,
    );
  }

  @override
  List<Object?> get props =>
      [firestorePath, reporterUid, kind, preview, targetAuthorUid, createdAt];
}
