import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/lesson_progress_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/model_manager.dart';
import '../../data/services/teaching_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppRepository _repository = AppRepository();
  LessonProgress? _recentProgress;
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final teachingState = Provider.of<TeachingState>(context, listen: false);
        if (teachingState.isSpeaking || teachingState.isPaused) {
          teachingState.leaveTeachingScreen();
        }
      }
    });
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final progress = await _repository.getMostRecentProgress();
    final subjects = await _repository.getAllSubjects();

    if (mounted) {
      setState(() {
        _recentProgress = progress;
        _subjects = subjects;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context);
    final teachingState = Provider.of<TeachingState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school, color: Color(0xFF1D4ED8), size: 20),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Teacher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Personal Exam Tutor', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          // Language selector toggle
          PopupMenuButton<AppLanguage>(
            tooltip: 'Language',
            initialValue: teachingState.language,
            onSelected: (lang) => teachingState.setLanguage(lang),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AppLanguage.english,
                child: Text('English'),
              ),
              const PopupMenuItem(
                value: AppLanguage.telugu,
                child: Text('Telugu (తెలుగు)'),
              ),
              const PopupMenuItem(
                value: AppLanguage.teluguEnglish,
                child: Text('English + Telugu'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 4),
                  Text(
                    teachingState.language.shortCode,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help / How to Use',
            onPressed: () => Navigator.pushNamed(context, '/help'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Greeting
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const Text(
                            'Ready for Exam Preparation?',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Model Status Pill Banner
                    _buildModelStatusBanner(context, modelManager),
                    const SizedBox(height: 16),

                    // Classroom Live Teacher Hero Card
                    _buildClassroomTeacherHero(context, teachingState),
                    const SizedBox(height: 16),

                    // Continue Learning Card
                    if (_recentProgress != null)
                      _buildContinueCard(context, _recentProgress!)
                    else
                      _buildEmptyProgressCard(context),

                    const SizedBox(height: 24),

                    // Quick Actions Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text(
                        'Quick Actions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionsGrid(context),

                    const SizedBox(height: 24),

                    // Recent Subjects Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Course Subjects',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/subjects'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSubjectsList(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModelStatusBanner(BuildContext context, ModelManager manager) {
    final isReady = manager.hasModelInstalled;
    final color = isReady ? Colors.green : Colors.amber.shade700;
    final text = isReady ? 'Local AI: Active (${manager.modelName})' : 'AI Model Setup Required';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/model_setup'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isReady ? Colors.green.shade50 : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(isReady ? Icons.offline_bolt : Icons.info_outline, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueCard(BuildContext context, LessonProgress progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CONTINUE LEARNING',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
                Text(
                  '${progress.percentInt}% Completed',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              progress.subjectTitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Text(
              progress.topicTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.percentComplete,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF1D4ED8),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _resumeLesson(progress),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume Lesson'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProgressCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start Your First Lesson',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a topic from your course or browse Algorithms to learn step-by-step.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/subjects'),
              child: const Text('Browse Subjects'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {'icon': Icons.menu_book, 'title': 'Learn', 'route': '/subjects', 'color': Colors.blue},
      {'icon': Icons.help_outline, 'title': 'Ask Doubt', 'route': '/chat', 'color': Colors.indigo},
      {'icon': Icons.quiz_outlined, 'title': 'Quiz', 'route': '/quiz', 'color': Colors.teal},
      {'icon': Icons.history_edu, 'title': 'Exam Prep', 'route': '/exam_prep', 'color': Colors.deepOrange},
      {'icon': Icons.replay, 'title': 'Revision', 'route': '/revision', 'color': Colors.amber.shade800},
      {'icon': Icons.folder_outlined, 'title': 'Materials', 'route': '/documents', 'color': Colors.purple},
      {'icon': Icons.troubleshoot, 'title': 'Diagnostics', 'route': '/diagnostics', 'color': const Color(0xFF16A34A)},
      {'icon': Icons.menu_book_outlined, 'title': 'How to Use', 'route': '/help', 'color': const Color(0xFF1D4ED8)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final item = actions[index];
          final color = item['color'] as Color;
          return InkWell(
            onTap: () => Navigator.pushNamed(context, item['route'] as String),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubjectsList(BuildContext context) {
    if (_subjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('No subjects added yet. Tap View All to create one.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _subjects.length > 3 ? 3 : _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Text(
                subject.code.isNotEmpty ? subject.code.substring(0, 2) : 'CS',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
              ),
            ),
            title: Text(subject.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${subject.topicCount} Topics Available', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/topic_list',
                arguments: {'subject': subject},
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildClassroomTeacherHero(BuildContext context, TeachingState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classroom AI Teacher',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Teacher speaks aloud with synchronized board notes',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.record_voice_over, size: 18),
                  label: const Text(
                    'Enter Topic',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _showTopicOnlyDialog(context, state),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.post_add, size: 18),
                  label: const Text(
                    'Paste Notes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/teach_material'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTopicOnlyDialog(BuildContext context, TeachingState state) {
    final topicController = TextEditingController();
    final notesController = TextEditingController();
    bool showNotesInput = false;
    AppLanguage selectedLang = state.language;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, color: Color(0xFF1D4ED8), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Start Classroom Teaching', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter any topic name. The teacher will build a complete syllabus and speak aloud while showing notes on screen:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: topicController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Topic Name',
                    hintText: 'e.g. Python, API, Binary Search, DBMS',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.menu_book),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Language: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    DropdownButton<AppLanguage>(
                      value: selectedLang,
                      underline: const SizedBox(),
                      items: AppLanguage.values.map((l) {
                        return DropdownMenuItem(
                          value: l,
                          child: Text(l.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (lang) {
                        if (lang != null) {
                          setDialogState(() => selectedLang = lang);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Expandable Study Notes (Optional)
                InkWell(
                  onTap: () => setDialogState(() => showNotesInput = !showNotesInput),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          showNotesInput ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: const Color(0xFF1D4ED8),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Paste Study Notes (Optional)',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showNotesInput) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Paste custom textbook paragraphs, notes, or syllabus (optional)...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Teaching'),
              onPressed: () async {
                final topic = topicController.text.trim();
                if (topic.isEmpty) return;

                Navigator.pop(ctx);
                await state.setLanguage(selectedLang);

                final notes = notesController.text.trim();
                bool success;
                if (notes.isNotEmpty) {
                  success = await state.startUserContentLesson(topic, notes);
                } else {
                  success = await state.startTopicOnlyLesson(topic);
                }

                if (context.mounted) {
                  if (success) {
                    Navigator.pushNamed(context, '/classroom');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.topicErrorMessage ?? 'Could not initialize lesson.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeLesson(LessonProgress progress) async {
    final subject = await _repository.getSubjectById(progress.subjectId);
    final topic = await _repository.getTopicWithSections(progress.topicId);

    if (!mounted) return;
    if (subject != null && topic != null) {
      final teachingState = Provider.of<TeachingState>(context, listen: false);
      await teachingState.loadTopicLesson(topic, subject);
      if (!mounted) return;
      Navigator.pushNamed(context, '/teacher');
    }
  }
}
