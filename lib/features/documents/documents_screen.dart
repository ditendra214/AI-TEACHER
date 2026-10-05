import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/document_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final AppRepository _repository = AppRepository();
  late final DocumentService _documentService;
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(repository: _repository);
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final list = await _repository.getAllDocuments();
    if (mounted) {
      setState(() {
        _documents = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _importDocument(String type) async {
    try {
      setState(() => _isImporting = true);
      final messenger = ScaffoldMessenger.of(context);

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == 'pdf' ? ['pdf'] : ['txt'],
        dialogTitle: 'Select ${type.toUpperCase()} File',
      );

      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final doc = await _documentService.importFile(originalPath: path);

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Successfully imported "${doc.name}" (${doc.chunkCount} sections indexed).'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDocuments();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showAddMaterialModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Study Material',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import your textbook or lecture notes. Text will be extracted and indexed offline for AI teaching.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text('Import PDF File', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Textbooks, class PPT handouts, syllabus notes'),
              onTap: () {
                Navigator.pop(ctx);
                _importDocument('pdf');
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.description, color: Colors.blue),
              ),
              title: const Text('Import TXT File', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Plain text summaries, question banks, markdown'),
              onTap: () {
                Navigator.pop(ctx);
                _importDocument('txt');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Remove "${doc.name}" from offline storage?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && doc.id != null) {
      await _repository.deleteDocument(doc.id!);
      _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No materials uploaded yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Import your semester PDF or TXT files. All content stays 100% offline on your phone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isImporting ? null : _showAddMaterialModal,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Material'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final isPdf = doc.fileType == 'pdf';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.description,
                            color: isPdf ? Colors.red : Colors.blue,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          doc.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${doc.formattedSize} • ${doc.chunkCount} indexed sections',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteDocument(doc),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/document_details',
                            arguments: {'document': doc},
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _showAddMaterialModal,
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: Text(_isImporting ? 'Processing...' : 'Add Material'),
      ),
    );
  }
}
