import 'package:equatable/equatable.dart';

/// Fields on `chats/{chatId}` used for roster + read receipts (not message bodies).
class FamilyChatMeta extends Equatable {
  const FamilyChatMeta({
    this.members = const {},
    this.readThrough = const {},
  });

  /// uid → display name (denormalized for UI).
  final Map<String, String> members;

  /// uid → time through which that member has read the thread.
  final Map<String, DateTime> readThrough;

  FamilyChatMeta copyWith({
    Map<String, String>? members,
    Map<String, DateTime>? readThrough,
  }) {
    return FamilyChatMeta(
      members: members ?? this.members,
      readThrough: readThrough ?? this.readThrough,
    );
  }

  @override
  List<Object?> get props => [members, readThrough];
}
