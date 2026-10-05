import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/teaching_state.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> with WidgetsBindingObserver {
  bool _showCheckAnswer = false;
  TeachingState? _teachingState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _teachingState = Provider.of<TeachingState>(context, listen: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _teachingState?.stopTeachingAudio();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teachingState?.leaveTeachingScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);
    final section = state.currentSection;

    if (section == null) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          state.leaveTeachingScreen();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Lesson'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                state.leaveTeachingScreen();
                Navigator.pop(context);
              },
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No active lesson sections loaded.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    state.leaveTeachingScreen();
                    Navigator.pop(context);
                  },
                  child: const Text('Back to Topics'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalSections = state.sections.length;
    final currentIdx = state.currentSectionIndex;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        state.leaveTeachingScreen();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              state.leaveTeachingScreen();
              Navigator.pop(context);
            },
          ),
          title: Column(
            children: [
            Text(
              state.activeTopic?.title ?? 'Lesson',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Section ${currentIdx + 1} of $totalSections',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Sections',
            icon: const Icon(Icons.list),
            onPressed: () => _showSectionsModal(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: totalSections > 0 ? (currentIdx + 1) / totalSections : 0,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF1D4ED8),
            minHeight: 4,
          ),

          // Main Lesson Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Title
                  Text(
                    section.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 1. Definition Card
                  _buildCard(
                    title: '1. Standard Definition',
                    icon: Icons.menu_book,
                    iconColor: Colors.blue,
                    content: section.definition,
                    backgroundColor: Colors.blue.shade50.withAlpha(80),
                  ),
                  const SizedBox(height: 12),

                  // 2. Importance in Exams
                  if (section.importance.isNotEmpty) ...[
                    _buildCard(
                      title: '2. Why It Matters in Semester Exams',
                      icon: Icons.stars,
                      iconColor: Colors.amber.shade800,
                      content: section.importance,
                      backgroundColor: Colors.amber.shade50.withAlpha(80),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Step-by-Step Explanation
                  _buildCard(
                    title: '3. Step-by-Step Explanation',
                    icon: Icons.lightbulb_outline,
                    iconColor: Colors.indigo,
                    content: section.explanation,
                  ),
                  const SizedBox(height: 12),

                  // 4. Real-World Example
                  if (section.example.isNotEmpty) ...[
                    _buildCard(
                      title: '4. Practical Example & Working',
                      icon: Icons.science_outlined,
                      iconColor: Colors.teal,
                      content: section.example,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 5. Telugu + English Explanation (Tanglish)
                  if (section.teluguExplanation.isNotEmpty) ...[
                    _buildCard(
                      title: '5. Telugu + English (Tanglish Summary)',
                      icon: Icons.translate,
                      iconColor: Colors.purple,
                      content: section.teluguExplanation,
                      backgroundColor: Colors.purple.shade50.withAlpha(80),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 6. Exam Points
                  if (section.examPoints.isNotEmpty) ...[
                    _buildCard(
                      title: '6. High-Scoring Exam Points',
                      icon: Icons.fact_check_outlined,
                      iconColor: Colors.deepOrange,
                      content: section.examPoints,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 7. Quick Check Question
                  if (section.checkQuestion.isNotEmpty) ...[
                    _buildCheckQuestionCard(section.checkQuestion, section.checkAnswer),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Control Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Previous Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: state.hasPreviousSection
                        ? () {
                            setState(() => _showCheckAnswer = false);
                            state.previousSection();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 8),

                // Ask Doubt Button (Core Interruption Feature)
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      state.enterDoubtMode();
                      Navigator.pushNamed(context, '/chat');
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Ask Doubt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Next Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showCheckAnswer = false);
                      if (state.hasNextSection) {
                        state.nextSection();
                      } else {
                        // Lesson finished
                        _showCompletedDialog(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(state.hasNextSection ? 'Next' : 'Finish'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckQuestionCard(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withAlpha(70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz, size: 18, color: Colors.green.shade800),
              const SizedBox(width: 8),
              Text(
                '7. Quick Check Question',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (!_showCheckAnswer)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showCheckAnswer = true),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Reveal Answer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      answer,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSectionsModal(BuildContext context, TeachingState state) {
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
            Text(
              '${state.activeTopic?.title ?? "Topic"} Sections',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: state.sections.length,
                itemBuilder: (context, idx) {
                  final isCurrent = idx == state.currentSectionIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: isCurrent ? const Color(0xFF1D4ED8) : Colors.grey.shade200,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      state.sections[idx].title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _showCheckAnswer = false);
                      state.jumpToSection(idx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Topic Completed! 🎉'),
        content: const Text(
          'Great job! You finished all sections in this topic. Test your knowledge with a quiz or review exam questions.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Course'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/quiz');
            },
            child: const Text('Take Topic Quiz'),
          ),
        ],
      ),
    );
  }
}
