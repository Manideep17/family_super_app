import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// `families/{fid}/polls/{pollId}` — quick family vote (2–4 options).
class FamilyPoll extends Equatable {
  const FamilyPoll({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    this.optionC,
    this.optionD,
    required this.createdBy,
    required this.createdAt,
    this.closed = false,
    this.closesAt,
    this.anonymous = false,
  });

  final String id;
  final String question;
  final String optionA;
  final String optionB;
  final String? optionC;
  final String? optionD;
  final String createdBy;
  final DateTime createdAt;
  final bool closed;
  final DateTime? closesAt;
  final bool anonymous;

  /// Active letter → label (min length 2 options: A and B).
  List<MapEntry<String, String>> get activeOptions {
    final out = <MapEntry<String, String>>[
      MapEntry('a', optionA),
      MapEntry('b', optionB),
    ];
    final c = optionC?.trim() ?? '';
    final d = optionD?.trim() ?? '';
    if (c.isNotEmpty) out.add(MapEntry('c', c));
    if (d.isNotEmpty) out.add(MapEntry('d', d));
    return out;
  }

  bool get isVotingClosed {
    if (closed) return true;
    final end = closesAt;
    if (end == null) return false;
    return !DateTime.now().isBefore(end);
  }

  static FamilyPoll fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final ts = d['createdAt'];
    final created = ts is Timestamp ? ts.toDate() : DateTime.now();
    final closesRaw = d['closesAt'];
    DateTime? closes;
    if (closesRaw is Timestamp) {
      closes = closesRaw.toDate();
    }
    return FamilyPoll(
      id: doc.id,
      question: (d['question'] as String? ?? '').trim(),
      optionA: (d['optionA'] as String? ?? 'A').trim(),
      optionB: (d['optionB'] as String? ?? 'B').trim(),
      optionC: (d['optionC'] as String?)?.trim(),
      optionD: (d['optionD'] as String?)?.trim(),
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: created,
      closed: d['closed'] == true,
      closesAt: closes,
      anonymous: d['anonymous'] == true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        question,
        optionA,
        optionB,
        optionC,
        optionD,
        createdBy,
        createdAt,
        closed,
        closesAt,
        anonymous,
      ];
}
