enum TeamRole {
  admin,
  member;

  String get value => name;

  static TeamRole fromString(String value) {
    return TeamRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => TeamRole.member,
    );
  }
}
