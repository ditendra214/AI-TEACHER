class Subject {
  final int? id;
  final String title;
  final String description;
  final String code;
  final DateTime createdAt;
  final int topicCount;

  const Subject({
    this.id,
    required this.title,
    this.description = '',
    this.code = '',
    required this.createdAt,
    this.topicCount = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'code': code,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Subject.fromMap(Map<String, dynamic> map, {int topicCount = 0}) {
    return Subject(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Untitled Subject',
      description: map['description'] as String? ?? '',
      code: map['code'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      topicCount: topicCount,
    );
  }

  Subject copyWith({
    int? id,
    String? title,
    String? description,
    String? code,
    DateTime? createdAt,
    int? topicCount,
  }) {
    return Subject(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      topicCount: topicCount ?? this.topicCount,
    );
  }
}
