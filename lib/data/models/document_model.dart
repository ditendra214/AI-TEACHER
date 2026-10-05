class DocumentModel {
  final int? id;
  final int? subjectId;
  final String name;
  final String fileType; // 'pdf' or 'txt'
  final String localPath;
  final int sizeBytes;
  final int pageCount;
  final DateTime importedAt;
  final int chunkCount;

  const DocumentModel({
    this.id,
    this.subjectId,
    required this.name,
    required this.fileType,
    required this.localPath,
    required this.sizeBytes,
    this.pageCount = 1,
    required this.importedAt,
    this.chunkCount = 0,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'subject_id': subjectId,
      'name': name,
      'file_type': fileType,
      'local_path': localPath,
      'size_bytes': sizeBytes,
      'page_count': pageCount,
      'imported_at': importedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map, {int chunkCount = 0}) {
    return DocumentModel(
      id: map['id'] as int?,
      subjectId: map['subject_id'] as int?,
      name: map['name'] as String? ?? 'Untitled',
      fileType: map['file_type'] as String? ?? 'txt',
      localPath: map['local_path'] as String? ?? '',
      sizeBytes: map['size_bytes'] as int? ?? 0,
      pageCount: map['page_count'] as int? ?? 1,
      importedAt: map['imported_at'] != null
          ? DateTime.tryParse(map['imported_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      chunkCount: chunkCount,
    );
  }
}

class DocumentChunkModel {
  final int? id;
  final int documentId;
  final int chunkIndex;
  final String content;
  final int wordCount;
  final int? pageNumber;

  const DocumentChunkModel({
    this.id,
    required this.documentId,
    required this.chunkIndex,
    required this.content,
    required this.wordCount,
    this.pageNumber,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'document_id': documentId,
      'chunk_index': chunkIndex,
      'content': content,
      'word_count': wordCount,
      'page_number': pageNumber,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory DocumentChunkModel.fromMap(Map<String, dynamic> map) {
    return DocumentChunkModel(
      id: map['id'] as int?,
      documentId: map['document_id'] as int? ?? 0,
      chunkIndex: map['chunk_index'] as int? ?? 0,
      content: map['content'] as String? ?? '',
      wordCount: map['word_count'] as int? ?? 0,
      pageNumber: map['page_number'] as int?,
    );
  }
}
