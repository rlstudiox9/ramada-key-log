class StaffRosterMember {
  final int id;
  final String name;
  final String hours;
  final bool isActive;

  const StaffRosterMember({
    required this.id,
    required this.name,
    required this.hours,
    required this.isActive,
  });

  factory StaffRosterMember.fromJson(Map<String, dynamic> json) =>
      StaffRosterMember(
        id: json['id'] as int,
        name: json['name'] as String,
        hours: json['hours'] as String,
        isActive: json['is_active'] as bool,
      );
}
