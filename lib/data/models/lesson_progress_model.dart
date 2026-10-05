class LessonProgress {
  final int? id;
  final int subjectId;
  final int topicId;
  final String subjectTitle;
  final String topicTitle;
  final int currentSectionIndex;
  final int totalSections;
  final bool isCompleted;
  final DateTime lastStudiedAt;

  const LessonProgress({
    this.id,
    required this.subjectId,
    required this.topicId,
    this.subjectTitle = '',
    this.topicTitle = '',
    required this.currentSectionIndex,
    required this.totalSections,
    this.isCompleted = false,
    required this.lastStudiedAt,
  });

  double get percentComplete {
    if (totalSections <= 0) return 0.0;
    final pct = (currentSectionIndex + 1) / totalSections;
    return pct > 1.0 ? 1.0 : pct;
  }

  int get percentInt => (percentComplete * 100).round();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'subject_id': subjectId,
      'topic_id': topicId,
      'current_section_index': currentSectionIndex,
      'total_sections': totalSections,
      'is_completed': isCompleted ? 1 : 0,
      'last_studied_at': lastStudiedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory LessonProgress.fromMap(
    Map<String, dynamic> map, {
    String subjectTitle = '',
    String topicTitle = '',
  }) {
    return LessonProgress(
      id: map['id'] as int?,
      subjectId: map['subject_id'] as int? ?? 0,
      topicId: map['topic_id'] as int? ?? 0,
      subjectTitle: subjectTitle,
      topicTitle: topicTitle,
      currentSectionIndex: map['current_section_index'] as int? ?? 0,
      totalSections: map['total_sections'] as int? ?? 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      lastStudiedAt: map['last_studied_at'] != null
          ? DateTime.tryParse(map['last_studied_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  LessonProgress copyWith({
    int? id,
    int? subjectId,
    int? topicId,
    String? subjectTitle,
    String? topicTitle,
    int? currentSectionIndex,
    int? totalSections,
    bool? isCompleted,
    DateTime? lastStudiedAt,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      topicTitle: topicTitle ?? this.topicTitle,
      currentSectionIndex: currentSectionIndex ?? this.currentSectionIndex,
      totalSections: totalSections ?? this.totalSections,
      isCompleted: isCompleted ?? this.isCompleted,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
    );
  }
}
