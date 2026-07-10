/// Role of a member within a single family.
enum FamilyRole { member }

extension FamilyRoleX on FamilyRole {
  String get wireName => 'member';

  static FamilyRole parse(String? raw) {
    return FamilyRole.member;
  }
}
