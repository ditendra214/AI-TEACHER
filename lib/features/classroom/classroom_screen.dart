import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/topic_model.dart';
import '../../data/services/teaching_state.dart';
import 'classroom_doubt_sheet.dart';

/// Dedicated Classroom Teaching Mode
/// Shows visual explanation on screen with high contrast while Android TTS speaks the explanation.
/// Supports immediate doubt interruption, audio playback controls, and sentence-by-sentence tracking.
class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> with WidgetsBindingObserver {
  TeachingState? _teachingState;
  final ScrollController _scrollController = ScrollController();
  int _lastSectionIndex = -1;

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);
    final section = state.currentSection;

    if (state.currentSectionIndex != _lastSectionIndex) {
      _lastSectionIndex = state.currentSectionIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    if (section == null) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          state.leaveTeachingScreen();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Classroom'),
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
                const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No active lesson loaded.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    state.leaveTeachingScreen();
                    Navigator.pop(context);
                  },
                  child: const Text('Back to Home'),
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
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
              state.activeTopic?.title ?? (state.isLineByLineMode ? 'Line-by-Line Notes' : 'Classroom Lesson'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              state.isLineByLineMode
                  ? 'Line ${currentIdx + 1} of $totalSections'
                  : 'Section ${currentIdx + 1} of $totalSections',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          // Auto-advance toggle
          IconButton(
            tooltip: state.autoAdvance ? 'Auto-Advance ON' : 'Auto-Advance OFF',
            icon: Icon(
              state.autoAdvance ? Icons.autorenew : Icons.playlist_play,
              color: state.autoAdvance ? const Color(0xFF1D4ED8) : Colors.grey,
            ),
            onPressed: () => state.setAutoAdvance(!state.autoAdvance),
          ),
          // Language Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.language.shortCode,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(state.isLineByLineMode ? Icons.format_list_numbered : Icons.menu_book_outlined),
            tooltip: state.isLineByLineMode ? 'All Lines' : 'All Sections',
            onPressed: () => _showSectionsModal(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // Section Progress Indicator
          LinearProgressIndicator(
            value: totalSections > 0 ? (currentIdx + 1) / totalSections : 0.0,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF1D4ED8),
            minHeight: 4,
          ),

          // Main Classroom Board
          Expanded(
            child: state.isLineByLineMode
                ? _buildLineByLineBoard(context, state, section, currentIdx, totalSections)
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  // Audio Status Banner (reflects actual native TTS state)
                  _buildAudioStatusBanner(context, state),
                  const SizedBox(height: 14),

                  // Missing Telugu Voice Notice
                  if ((state.language == AppLanguage.telugu || state.language == AppLanguage.teluguEnglish) &&
                      !state.hasTeluguVoice)
                    _buildMissingVoiceWarning(context, state),

                  // Section Title (High Contrast)
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Teacher Explanation Card with Granular Sentence Highlighting
                  _buildTeacherCard(state),
                  const SizedBox(height: 16),

                  // 2. Standard Definition & Principles Card
                  _buildContentCard(
                    title: 'Core Concept & Definition',
                    icon: Icons.menu_book,
                    iconColor: const Color(0xFF1D4ED8),
                    body: section.definition,
                    bgColor: Colors.white,
                    borderColor: Colors.blue.shade200,
                  ),
                  const SizedBox(height: 14),

                  // 3. Concrete Example or Walkthrough Card
                  if (section.example.isNotEmpty) ...[
                    _buildContentCard(
                      title: 'Practical Example',
                      icon: Icons.lightbulb_outline,
                      iconColor: const Color(0xFFD97706),
                      body: section.example,
                      bgColor: Colors.white,
                      borderColor: Colors.amber.shade300,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. Formula / Visual / Code Card
                  if (section.visualAid != null && section.visualAid!.isNotEmpty) ...[
                    _buildCodeCard('Governing Formula / Structure', section.visualAid!),
                    const SizedBox(height: 14),
                  ],

                  // 5. Semester Exam High-Yield Card
                  if (section.examPoints.isNotEmpty) ...[
                    _buildContentCard(
                      title: 'Semester Exam Focus Points',
                      icon: Icons.star_outline,
                      iconColor: const Color(0xFF7C3AED),
                      body: section.examPoints,
                      bgColor: Colors.white,
                      borderColor: Colors.purple.shade200,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),

          // Classroom Bottom Controls Dock
          _buildBottomDock(context, state),
        ],
      ),
    ),
  );
}

  Widget _buildAudioStatusBanner(BuildContext context, TeachingState state) {
    if (state.hasPlaybackError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.ttsErrorMessage ?? 'Voice playback failed.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => state.replayTeachingAudio(),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final isSpeaking = state.isSpeaking;
    final isPaused = state.isPaused;
    final isCompleted = state.ttsService.isCompleted;

    final bgColor = isSpeaking
        ? Colors.green.shade50
        : (isPaused ? Colors.amber.shade50 : (isCompleted ? Colors.teal.shade50 : Colors.blue.shade50));
    final borderColor = isSpeaking
        ? Colors.green.shade300
        : (isPaused ? Colors.amber.shade300 : (isCompleted ? Colors.teal.shade300 : Colors.blue.shade200));
    final textColor = isSpeaking
        ? Colors.green.shade900
        : (isPaused ? Colors.amber.shade900 : (isCompleted ? Colors.teal.shade900 : Colors.blue.shade900));
    final iconData = isSpeaking
        ? Icons.volume_up
        : (isPaused ? Icons.pause_circle_filled : (isCompleted ? Icons.check_circle : Icons.volume_up_outlined));
    final labelText = isSpeaking
        ? 'Teacher is speaking...'
        : (isPaused ? 'Teacher paused' : (isCompleted ? '✓ Section completed' : 'Voice ready'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(iconData, color: textColor, size: 18),
          const SizedBox(width: 8),
          Text(
            labelText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          Text(
            state.language.displayName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingVoiceWarning(BuildContext context, TeachingState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Telugu voice is not installed on this phone.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => state.openTtsSettings(),
            child: const Text('Configure Voice', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(TeachingState state) {
    final segments = state.currentSectionSegments;
    final currentSegIdx = state.currentSegmentIndex;
    final isSpeaking = state.isSpeaking;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D4ED8).withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withAlpha(12),
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
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Teacher Explanation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const Spacer(),
              if (isSpeaking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Speaking ${currentSegIdx + 1}/${segments.isNotEmpty ? segments.length : 1}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Rich segmented text display with active sentence highlighting
          if (segments.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 6,
              children: segments.asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;
                final isCurrent = idx == currentSegIdx && isSpeaking;

                return Container(
                  padding: isCurrent
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                      : EdgeInsets.zero,
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1D4ED8).withAlpha(100)),
                        )
                      : null,
                  child: Text(
                    '$text ',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Text(
              state.currentSpokenScript,
              style: const TextStyle(fontSize: 15, height: 1.55, color: Color(0xFF0F172A)),
            ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String body,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A), // High contrast dark text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF38BDF8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context, TeachingState state) {
    final isSpeaking = state.isSpeaking;
    final isPaused = state.isPaused;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Audio Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replay
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: 'Replay Section Audio',
                  onPressed: () => state.replayTeachingAudio(),
                ),
                const SizedBox(width: 8),

                // Play / Pause / Resume
                if (isSpeaking)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade100),
                    icon: const Icon(Icons.pause, color: Colors.amber),
                    label: const Text('Pause', style: TextStyle(color: Colors.black)),
                    onPressed: () => state.pauseTeachingAudio(),
                  )
                else if (isPaused)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade100),
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    label: const Text('Resume', style: TextStyle(color: Colors.black)),
                    onPressed: () => state.resumeTeachingAudio(),
                  )
                else
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade100),
                    icon: const Icon(Icons.volume_up, color: Color(0xFF1D4ED8)),
                    label: const Text('Speak Aloud', style: TextStyle(color: Color(0xFF1D4ED8))),
                    onPressed: () => state.playCurrentSectionAudio(),
                  ),

                const SizedBox(width: 8),
                // Stop
                IconButton(
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop Audio',
                  onPressed: isSpeaking || isPaused ? () => state.stopTeachingAudio() : null,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Ask Doubt + Navigation
            Row(
              children: [
                // Previous Section Button
                IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: state.isLineByLineMode ? 'Previous Line' : 'Previous Section',
                  onPressed: state.hasPreviousSection ? () => state.previousSection() : null,
                ),
                const SizedBox(width: 10),

                // Ask Doubt (Prominent Center Button)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.mic, size: 20),
                      label: const Text(
                        'Ask Doubt',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () {
                        state.enterClassroomDoubt();
                        ClassroomDoubtSheet.show(context);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Next Section Button
                IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: state.isLineByLineMode ? 'Next Line' : 'Next Section',
                  onPressed: state.hasNextSection ? () => state.nextSection() : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineByLineBoard(
    BuildContext context,
    TeachingState state,
    LessonSection section,
    int currentIdx,
    int totalSections,
  ) {
    final originalText = section.originalText ?? section.definition;
    final isSpeaking = state.isSpeaking;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Audio Status Banner (reflects actual native TTS state)
          _buildAudioStatusBanner(context, state),
          const SizedBox(height: 12),

          // Missing Telugu Voice Notice
          if ((state.language == AppLanguage.telugu || state.language == AppLanguage.teluguEnglish) &&
              !state.hasTeluguVoice)
            _buildMissingVoiceWarning(context, state),

          // Line Counter & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Line ${currentIdx + 1} of $totalSections',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_list_numbered, size: 14, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 4),
                    Text(
                      'Sequential Notes',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. ORIGINAL CONTENT Card (Student's exact line)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSpeaking ? const Color(0xFFFEF3C7) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSpeaking ? const Color(0xFFF59E0B) : const Color(0xFF93C5FD),
                width: isSpeaking ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSpeaking
                      ? const Color(0xFFF59E0B).withAlpha(30)
                      : Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 18,
                      color: isSpeaking ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'YOUR CONTENT (Line ${currentIdx + 1})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isSpeaking ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                      ),
                    ),
                    const Spacer(),
                    if (isSpeaking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Now Teaching',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  originalText,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: isSpeaking ? const Color(0xFF78350F) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. TEACHER EXPLANATION Card
          _buildTeacherCard(state),
          const SizedBox(height: 14),

          // 3. Optional Example or Exam Points
          if (section.example.isNotEmpty) ...[
            _buildContentCard(
              title: 'Classroom Analogy / Example',
              icon: Icons.lightbulb_outline,
              iconColor: const Color(0xFFD97706),
              body: section.example,
              bgColor: Colors.white,
              borderColor: Colors.amber.shade300,
            ),
            const SizedBox(height: 14),
          ],

          if (section.examPoints.isNotEmpty) ...[
            _buildContentCard(
              title: 'Exam Key Points',
              icon: Icons.star_outline,
              iconColor: const Color(0xFF7C3AED),
              body: section.examPoints,
              bgColor: Colors.white,
              borderColor: Colors.purple.shade200,
            ),
            const SizedBox(height: 14),
          ],

          // 4. Sequential Notes Overview (All Lines in Note)
          _buildNotesSequenceCard(state, currentIdx, totalSections),
        ],
      ),
    );
  }

  Widget _buildNotesSequenceCard(TeachingState state, int currentIdx, int totalSections) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.format_list_bulleted, color: Color(0xFF1D4ED8), size: 20),
          title: Text(
            'All Lines in Your Notes ($totalSections)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
          ),
          subtitle: Text(
            'Active: Line ${currentIdx + 1}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          children: [
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.sections.length,
              itemBuilder: (ctx, idx) {
                final item = state.sections[idx];
                final isActive = idx == currentIdx;
                final text = item.originalText ?? item.definition;

                return InkWell(
                  onTap: () => state.jumpToSection(idx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? const Color(0xFF1D4ED8) : Colors.grey.shade200,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF1D4ED8) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'L${idx + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        if (isActive && state.isSpeaking)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.volume_up, size: 16, color: Color(0xFF1D4ED8)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSectionsModal(BuildContext context, TeachingState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    state.isLineByLineMode ? Icons.format_list_numbered : Icons.menu_book,
                    color: const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isLineByLineMode ? 'Study Notes Lines' : 'Lesson Sections',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    state.isLineByLineMode
                        ? '${state.sections.length} Lines'
                        : '${state.sections.length} Sections',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: state.sections.length,
                itemBuilder: (c, idx) {
                  final s = state.sections[idx];
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
                      state.isLineByLineMode ? 'Line ${idx + 1}' : s.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      s.originalText ?? s.definition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: isCurrent ? const Icon(Icons.volume_up, color: Color(0xFF1D4ED8), size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
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
}
