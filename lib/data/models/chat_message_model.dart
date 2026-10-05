class ChatMessage {
  final int? id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isDoubt;
  final String? contextTag;

  const ChatMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isDoubt = false,
    this.contextTag,
  });

  bool get isUser => role == 'user';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_doubt': isDoubt ? 1 : 0,
      'context_tag': contextTag,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String? ?? 'default',
      role: map['role'] as String? ?? 'user',
      content: map['content'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDoubt: (map['is_doubt'] as int? ?? 0) == 1,
      contextTag: map['context_tag'] as String?,
    );
  }
}
