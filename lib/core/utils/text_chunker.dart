/// Utility to clean and split text into manageable overlapping chunks for RAG
class TextChunk {
  final int index;
  final String text;
  final int wordCount;
  final int? pageNumber;

  const TextChunk({
    required this.index,
    required this.text,
    required this.wordCount,
    this.pageNumber,
  });

  Map<String, dynamic> toMap(int documentId) {
    return {
      'document_id': documentId,
      'chunk_index': index,
      'content': text,
      'word_count': wordCount,
      'page_number': pageNumber,
    };
  }
}

class TextChunker {
  /// Cleans raw extracted text from PDFs/TXTs
  static String cleanText(String raw) {
    if (raw.isEmpty) return '';

    // Normalize newlines and tabs
    String text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remove excessive null/control characters
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

    // Collapse more than 2 consecutive newlines into 2
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Collapse multiple horizontal spaces/tabs into a single space
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return text.trim();
  }

  /// Splits text into overlapping chunks
  /// [targetChunkWords]: target word size per chunk (default: 300 words)
  /// [overlapWords]: overlap between adjacent chunks (default: 50 words)
  static List<TextChunk> chunkText(
    String rawText, {
    int targetChunkWords = 300,
    int overlapWords = 50,
    int? pageNumber,
  }) {
    final cleaned = cleanText(rawText);
    if (cleaned.isEmpty) return [];

    final List<TextChunk> chunks = [];

    // Flatten into words
    final allWords = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (allWords.length <= targetChunkWords) {
      chunks.add(TextChunk(
        index: 0,
        text: cleaned,
        wordCount: allWords.length,
        pageNumber: pageNumber,
      ));
      return chunks;
    }

    int start = 0;
    int chunkIndex = 0;

    while (start < allWords.length) {
      int end = start + targetChunkWords;
      if (end > allWords.length) {
        end = allWords.length;
      }

      final chunkWords = allWords.sublist(start, end);
      final chunkText = chunkWords.join(' ');

      chunks.add(TextChunk(
        index: chunkIndex++,
        text: chunkText,
        wordCount: chunkWords.length,
        pageNumber: pageNumber,
      ));

      if (end == allWords.length) {
        break;
      }

      // Step forward by chunk size minus overlap
      start += (targetChunkWords - overlapWords);
    }

    return chunks;
  }
}
