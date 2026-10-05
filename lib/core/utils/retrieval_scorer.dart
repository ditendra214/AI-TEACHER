import 'dart:math';

/// Represents a chunk with its computed relevance score
class ScoredChunk {
  final int chunkId;
  final int documentId;
  final int chunkIndex;
  final String content;
  final int? pageNumber;
  final double score;

  const ScoredChunk({
    required this.chunkId,
    required this.documentId,
    required this.chunkIndex,
    required this.content,
    this.pageNumber,
    required this.score,
  });
}

class RetrievalScorer {
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'is', 'are', 'was', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'to', 'from',
    'in', 'out', 'on', 'off', 'over', 'under', 'again', 'further', 'then',
    'once', 'here', 'there', 'when', 'where', 'why', 'how', 'all', 'any',
    'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such', 'no',
    'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very', 's',
    't', 'can', 'will', 'just', 'don', 'should', 'now', 'of', 'for', 'with',
    'as', 'by', 'at', 'this', 'that', 'these', 'those', 'it', 'its',
  };

  /// Tokenizes a string into lowercased alphanumeric keywords without stop words
  static List<String> tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toList();
  }

  /// Scores a collection of chunks against a query using BM25-style relevance scoring
  /// [query]: user question or topic
  /// [chunks]: list of chunk maps from SQLite (containing 'id', 'document_id', 'chunk_index', 'content', 'page_number')
  /// [topK]: maximum number of chunks to return (default: 4)
  static List<ScoredChunk> retrieveTopChunks(
    String query,
    List<Map<String, dynamic>> chunks, {
    int topK = 4,
  }) {
    if (query.trim().isEmpty || chunks.isEmpty) return [];

    final queryTerms = tokenize(query);
    if (queryTerms.isEmpty) {
      // If all query terms were stopwords, use raw words
      final fallbackTerms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (fallbackTerms.isEmpty) return [];
      queryTerms.addAll(fallbackTerms);
    }

    final int totalDocs = chunks.length;

    // Document frequencies: how many chunks contain term t
    final Map<String, int> docFreq = {};
    final List<List<String>> tokenizedDocs = [];
    double totalDocLength = 0;

    for (final chunk in chunks) {
      final text = (chunk['content'] as String? ?? '');
      final tokens = tokenize(text);
      tokenizedDocs.add(tokens);
      totalDocLength += tokens.length;

      final uniqueTokens = tokens.toSet();
      for (final t in uniqueTokens) {
        docFreq[t] = (docFreq[t] ?? 0) + 1;
      }
    }

    final double avgDocLength = totalDocs > 0 ? (totalDocLength / totalDocs) : 1.0;

    // BM25 parameters
    const double k1 = 1.2;
    const double b = 0.75;

    final List<ScoredChunk> scoredList = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunkMap = chunks[i];
      final docTokens = tokenizedDocs[i];
      final docLength = docTokens.length;
      final rawContent = chunkMap['content'] as String? ?? '';

      // Term frequencies in this chunk
      final Map<String, int> tf = {};
      for (final t in docTokens) {
        tf[t] = (tf[t] ?? 0) + 1;
      }

      double score = 0.0;

      for (final term in queryTerms) {
        if (tf.containsKey(term)) {
          final count = tf[term]!;
          final df = docFreq[term] ?? 1;

          // IDF calculation with smoothing
          final idf = log((totalDocs - df + 0.5) / (df + 0.5) + 1.0);

          // BM25 TF component
          final tfComponent = (count * (k1 + 1.0)) /
              (count + k1 * (1.0 - b + b * (docLength / (avgDocLength > 0 ? avgDocLength : 1.0))));

          score += idf * tfComponent;
        }
      }

      // Bonus for exact substring match of query
      if (rawContent.toLowerCase().contains(query.toLowerCase().trim())) {
        score += 3.0;
      }

      if (score > 0) {
        scoredList.add(ScoredChunk(
          chunkId: chunkMap['id'] as int? ?? 0,
          documentId: chunkMap['document_id'] as int? ?? 0,
          chunkIndex: chunkMap['chunk_index'] as int? ?? 0,
          content: rawContent,
          pageNumber: chunkMap['page_number'] as int?,
          score: score,
        ));
      }
    }

    // Sort descending by score
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    if (scoredList.length > topK) {
      return scoredList.sublist(0, topK);
    }

    return scoredList;
  }
}
