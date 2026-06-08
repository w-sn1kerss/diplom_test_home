class Achievement {
  final String id;
  final String title;
  final String? description;
  final String? iconUrl;
  final String? requirementCode;
  final DateTime? earnedAt;

  const Achievement({
    required this.id,
    required this.title,
    this.description,
    this.iconUrl,
    this.requirementCode,
    this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    iconUrl: json['icon_url'] as String?,
    requirementCode: json['requirement_code'] as String?,
    earnedAt: json['earned_at'] != null
        ? DateTime.parse(json['earned_at'] as String)
        : null,
  );
}