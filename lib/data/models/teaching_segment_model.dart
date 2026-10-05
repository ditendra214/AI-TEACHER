/// Represents a discrete pedagogical speech and visual segment
/// for Line-by-Line teaching mode.
class TeachingSegment {
  final String segmentId;
  final String originalText;
  final String teacherExplanation;
  final String speechText;
  final int sectionIndex;
  final int paragraphIndex;
  final int lineIndex;

  const TeachingSegment({
    required this.segmentId,
    required this.originalText,
    required this.teacherExplanation,
    required this.speechText,
    required this.sectionIndex,
    this.paragraphIndex = 0,
    this.lineIndex = 0,
  });

  Map<String, dynamic> toMap() => {
    'segmentId': segmentId,
    'originalText': originalText,
    'teacherExplanation': teacherExplanation,
    'speechText': speechText,
    'sectionIndex': sectionIndex,
    'paragraphIndex': paragraphIndex,
    'lineIndex': lineIndex,
  };

  factory TeachingSegment.fromMap(Map<String, dynamic> map) => TeachingSegment(
    segmentId: map['segmentId'] as String? ?? '',
    originalText: map['originalText'] as String? ?? '',
    teacherExplanation: map['teacherExplanation'] as String? ?? '',
    speechText: map['speechText'] as String? ?? '',
    sectionIndex: map['sectionIndex'] as int? ?? 0,
    paragraphIndex: map['paragraphIndex'] as int? ?? 0,
    lineIndex: map['lineIndex'] as int? ?? 0,
  );

  TeachingSegment copyWith({
    String? segmentId,
    String? originalText,
    String? teacherExplanation,
    String? speechText,
    int? sectionIndex,
    int? paragraphIndex,
    int? lineIndex,
  }) {
    return TeachingSegment(
      segmentId: segmentId ?? this.segmentId,
      originalText: originalText ?? this.originalText,
      teacherExplanation: teacherExplanation ?? this.teacherExplanation,
      speechText: speechText ?? this.speechText,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      lineIndex: lineIndex ?? this.lineIndex,
    );
  }
}
