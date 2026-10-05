import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/content_understanding_service.dart';
import '../../data/services/teaching_state.dart';

enum NotesTeachingMode {
  explainAndTeach,
  lineByLine,
}

/// Screen for Mode B & C: Teach My Material / Line-by-Line Notes
/// User content is the PRIMARY SOURCE. Topic name is strictly OPTIONAL.
class TeachMaterialScreen extends StatefulWidget {
  final String? initialTopic;
  final String? initialContent;
  final bool initialLineByLine;

  const TeachMaterialScreen({
    super.key,
    this.initialTopic,
    this.initialContent,
    this.initialLineByLine = false,
  });

  @override
  State<TeachMaterialScreen> createState() => _TeachMaterialScreenState();
}

class _TeachMaterialScreenState extends State<TeachMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _topicController;
  late final TextEditingController _contentController;
  late NotesTeachingMode _selectedMode;
  bool _isProcessing = false;
  String _detectedTopicPreview = '';

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _selectedMode = widget.initialLineByLine ? NotesTeachingMode.lineByLine : NotesTeachingMode.explainAndTeach;

    _contentController.addListener(_updateTopicPreview);
    _updateTopicPreview();
  }

  void _updateTopicPreview() {
    if (_topicController.text.trim().isEmpty && _contentController.text.trim().isNotEmpty) {
      final detected = ContentUnderstandingService.inferTopicTitle(_contentController.text);
      if (detected != _detectedTopicPreview) {
        setState(() {
          _detectedTopicPreview = detected;
        });
      }
    } else if (_detectedTopicPreview.isNotEmpty && _topicController.text.trim().isNotEmpty) {
      setState(() {
        _detectedTopicPreview = '';
      });
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_updateTopicPreview);
    _topicController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _startTeaching(TeachingState state) async {
    if (!_formKey.currentState!.validate()) return;

    final topic = _topicController.text.trim();
    final content = _contentController.text.trim();

    setState(() => _isProcessing = true);

    final success = _selectedMode == NotesTeachingMode.lineByLine
        ? await state.startLineByLineLesson(
            topic.isNotEmpty ? topic : null,
            content,
          )
        : await state.startUserContentLesson(
            topic.isNotEmpty ? topic : null,
            content,
          );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.pushReplacementNamed(context, '/classroom');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teach My Material'),
        actions: [
          // Language selector toggle
          PopupMenuButton<AppLanguage>(
            tooltip: 'Teaching Language',
            initialValue: state.language,
            onSelected: (lang) => state.setLanguage(lang),
            itemBuilder: (_) => AppLanguage.values.map((l) {
              return PopupMenuItem(
                value: l,
                child: Text(l.displayName),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 4),
                  Text(
                    state.language.shortCode,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.school, color: Color(0xFF1D4ED8), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Material is the Primary Source',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The classroom teacher explains your notes section by section in ${state.language.displayName}, with real voice delivery and doubt support.',
                            style: TextStyle(fontSize: 12.5, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. Study Material Multi-line Field (PRIMARY INPUT)
              const Text(
                'Study Material',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText:
                      'Paste your notes, textbook paragraphs, definitions, or code here...\n\nExample:\n"Python is a high-level programming language. It supports object-oriented programming..."',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter or paste your study content';
                  }
                  if (val.trim().length < 15) {
                    return 'Please provide at least a few sentences of study material';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. Optional Topic Name Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Optional Topic Name',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  if (_detectedTopicPreview.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Detected: $_detectedTopicPreview',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _topicController,
                decoration: InputDecoration(
                  hintText: _detectedTopicPreview.isNotEmpty
                      ? 'Auto-detected: $_detectedTopicPreview (or type custom title)'
                      : 'e.g. Python Programming (Optional)',
                  prefixIcon: const Icon(Icons.topic_outlined),
                  border: const OutlineInputBorder(),
                ),
                // Notice: No validator! Topic name is strictly optional!
              ),
              const SizedBox(height: 16),

              // 3. Teaching Language Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    const Text('Language:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    const Spacer(),
                    DropdownButton<AppLanguage>(
                      value: state.language,
                      isDense: true,
                      underline: const SizedBox(),
                      onChanged: (lang) {
                        if (lang != null) state.setLanguage(lang);
                      },
                      items: AppLanguage.values.map((l) {
                        return DropdownMenuItem(
                          value: l,
                          child: Text(l.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Teaching Mode Selector
              const Text(
                'Teaching Mode',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildModeCard(
                      title: 'Explain & Teach',
                      subtitle: 'Structured breakdown & concepts',
                      icon: Icons.menu_book,
                      isSelected: _selectedMode == NotesTeachingMode.explainAndTeach,
                      onTap: () => setState(() => _selectedMode = NotesTeachingMode.explainAndTeach),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModeCard(
                      title: 'Teach Line-by-Line',
                      subtitle: 'Every sentence in sequential order',
                      icon: Icons.format_list_numbered,
                      isSelected: _selectedMode == NotesTeachingMode.lineByLine,
                      onTap: () => setState(() => _selectedMode = NotesTeachingMode.lineByLine),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Start Teaching Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_circle_fill, size: 24),
                  label: Text(
                    _isProcessing
                        ? (_selectedMode == NotesTeachingMode.lineByLine
                            ? 'Preparing Line-by-Line...'
                            : 'Decomposing Content...')
                        : 'Start Teaching',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessing ? null : () => _startTeaching(state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF1D4ED8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: isSelected ? activeColor : Colors.grey.shade600),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 18, color: activeColor)
                else
                  Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? activeColor : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
