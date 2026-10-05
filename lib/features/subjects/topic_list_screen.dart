import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/document_service.dart';
import '../../data/services/teaching_state.dart';

class TopicListScreen extends StatefulWidget {
  final Subject subject;

  const TopicListScreen({super.key, required this.subject});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  final AppRepository _repository = AppRepository();
  late final DocumentService _documentService;
  List<Topic> _topics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(repository: _repository);
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    final list = await _repository.getTopicsForSubject(widget.subject.id ?? 0);
    if (mounted) {
      setState(() {
        _topics = list;
        _isLoading = false;
      });
    }
  }

  void _showAddTopicDialog() {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Topic Title *',
                hintText: 'e.g., Dynamic Programming',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: summaryController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short Summary / Notes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final topic = Topic(
                  subjectId: widget.subject.id ?? 0,
                  title: title,
                  summary: summaryController.text.trim(),
                  orderIndex: _topics.length,
                );
                final topicId = await _repository.insertTopic(topic);

                // Add default lesson section
                await _repository.insertLessonSection(
                  LessonSection(
                    topicId: topicId,
                    title: 'Concept Overview',
                    definition: '$title is a key concept in ${widget.subject.title}.',
                    importance: 'Essential for understanding the syllabus and scoring in exam questions.',
                    explanation: 'Study the foundational properties, implementation steps, and typical problem formulations.',
                    example: 'Standard textbook illustrations and exam problems.',
                    teluguExplanation: '$title gurinchi basic concept and exam ki kavalsina important points.',
                    examPoints: '• Clearly memorize the standard definition.\n• Note all assumptions and limitations.',
                    checkQuestion: 'What is the primary purpose of $title?',
                    checkAnswer: 'To solve computational challenges efficiently.',
                    sectionOrder: 0,
                  ),
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadTopics();
              }
            },
            child: const Text('Save Topic'),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeMaterialAndSuggestTopics() async {
    final docs = await _repository.getAllDocuments();
    if (docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No study materials uploaded yet. Upload a PDF or TXT first.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analyze Material for Topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an uploaded document to extract syllabus topics automatically:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...docs.map(
              (d) => ListTile(
                leading: Icon(
                  d.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                  color: d.fileType == 'pdf' ? Colors.red : Colors.blue,
                ),
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${d.chunkCount} indexed sections • ${d.formattedSize}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  _runMaterialAnalysis(d.id!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMaterialAnalysis(int documentId) async {
    setState(() => _isLoading = true);
    try {
      final suggested = await _documentService.suggestTopicsFromDocument(documentId);
      for (int i = 0; i < suggested.length; i++) {
        final title = suggested[i];
        final topic = Topic(
          subjectId: widget.subject.id ?? 0,
          title: title,
          summary: 'Extracted from study material analysis.',
          orderIndex: _topics.length + i,
        );
        final topicId = await _repository.insertTopic(topic);

        await _repository.insertLessonSection(
          LessonSection(
            topicId: topicId,
            title: title,
            definition: 'Key concept in ${widget.subject.title} derived from your uploaded notes.',
            importance: 'Frequently examined in university syllabus.',
            explanation: 'Review the extracted passages and practice writing structured answers.',
            teluguExplanation: 'Ee topic ni exam lo short and long answer questions ga adugutaru.',
            examPoints: '• Highlight step-by-step points in answer sheets.',
            sectionOrder: 0,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${suggested.length} syllabus topics from material!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _loadTopics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.title),
        actions: [
          IconButton(
            tooltip: 'Analyze Material',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _analyzeMaterialAndSuggestTopics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_list_bulleted, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No topics in this subject',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add topics manually or analyze an imported PDF.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showAddTopicDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Topic'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _analyzeMaterialAndSuggestTopics,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Analyze Material'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: topic.isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                          child: Icon(
                            topic.isCompleted ? Icons.check : Icons.school_outlined,
                            color: topic.isCompleted ? Colors.green : const Color(0xFF1D4ED8),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          topic.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${topic.sections.length} Sections • ${topic.isCompleted ? "Completed" : "In Progress"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: topic.isCompleted ? Colors.green : Colors.grey.shade600,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () async {
                          final teachingState = Provider.of<TeachingState>(this.context, listen: false);
                          await teachingState.loadTopicLesson(topic, widget.subject);
                          if (mounted) {
                            Navigator.pushNamed(this.context, '/teacher').then((_) => _loadTopics());
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTopicDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Topic'),
      ),
    );
  }
}
