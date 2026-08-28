class Project {
  final int? id;
  final String uuid;
  final String name;
  final String? description;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  Project({
    this.id,
    required this.uuid,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });
}


