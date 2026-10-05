import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/teaching_state.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final DocumentModel document;

  const DocumentDetailsScreen({super.key, required this.document});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final AppRepository _repository = AppRepository();
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);
    final list = await _repository.getChunksForDocument(widget.document.id ?? 0);
    if (mounted) {
      setState(() {
        _chunks = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _teachDocumentInClassroom() async {
    if (_chunks.isEmpty) return;
    final combined = _chunks.map((c) => c['content'] as String? ?? '').join('\n\n');
    final state = Provider.of<TeachingState>(context, listen: false);
    final title = widget.document.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final success = await state.startUserContentLesson(title, combined);
    if (success && mounted) {
      Navigator.pushNamed(context, '/classroom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _chunks.where((c) {
      if (_searchQuery.isEmpty) return true;
      final text = (c['content'] as String? ?? '').toLowerCase();
      return text.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Teach Document in Classroom',
            onPressed: _teachDocumentInClassroom,
          ),
        ],
      ),
      floatingActionButton: _chunks.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Teach Aloud'),
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              onPressed: _teachDocumentInClassroom,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Summary Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.document.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                            color: widget.document.fileType == 'pdf' ? Colors.red : Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.document.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.document.formattedSize} • ${_chunks.length} Extracted Chunks',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search indexed passages...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          fillColor: Colors.grey.shade100,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Extracted Chunks List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matching text passages found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final chunk = filtered[index];
                            final text = chunk['content'] as String? ?? '';
                            final chunkIdx = chunk['chunk_index'] as int? ?? index;

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Section ${chunkIdx + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${chunk['word_count'] ?? 0} words',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      text,
                                      style: const TextStyle(fontSize: 13, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
