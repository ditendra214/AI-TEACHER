import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/teaching_state.dart';
import '../../data/services/speech_service.dart';

/// Interactive Classroom Doubt Sheet
/// Pauses classroom audio, captures exact context, supports mic speech-to-text
/// and typed doubt input, displays & speaks the answer, and provides [Continue Lesson].
class ClassroomDoubtSheet extends StatefulWidget {
  const ClassroomDoubtSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ClassroomDoubtSheet(),
    );
  }

  @override
  State<ClassroomDoubtSheet> createState() => _ClassroomDoubtSheetState();
}

class _ClassroomDoubtSheetState extends State<ClassroomDoubtSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final SpeechService _speechService = SpeechService();
  String? _statusNotice;
  bool _isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _speechService.addListener(_onSpeechServiceChanged);
    _initSpeech();
  }

  void _onSpeechServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSpeech() async {
    await _speechService.init();
  }

  @override
  void dispose() {
    _speechService.removeListener(_onSpeechServiceChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  void _handleMicTap(TeachingState state) async {
    if (_speechService.isListening) {
      await _speechService.stopListening();
    } else {
      setState(() {
        _statusNotice = null;
        _isPermissionError = false;
      });

      await _speechService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _textController.text = text;
            });
          }
        },
        onError: (error, isPermission) {
          if (mounted) {
            setState(() {
              _statusNotice = error;
              _isPermissionError = isPermission;
            });
          }
        },
      );
    }
  }

  void _submitDoubt(TeachingState state) {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    setState(() {
      _statusNotice = null;
      _isPermissionError = false;
    });

    state.askClassroomDoubt(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);
    final isGenerating = state.isGenerating;
    final activeQuestion = state.activeDoubtQuestion;
    final activeAnswer = state.isGenerating
        ? state.streamingBuffer
        : (state.activeDoubtAnswer ?? (state.messages.isNotEmpty ? state.messages.last.content : null));

    final currentSection = state.currentSection;
    final sectionTitle = currentSection?.title ?? state.interruptedSectionTitle ?? 'Current Lesson';
    final isListening = _speechService.isListening;
    final isSpeakingAnswer = state.isSpeaking && activeAnswer != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE11D48).withAlpha(25),
                  child: const Icon(Icons.help_outline, color: Color(0xFFE11D48), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isLineByLineMode ? 'Doubt on Current Line' : 'Classroom Doubt',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        state.isLineByLineMode
                            ? 'Paused at Line ${(currentSection?.segment?.lineIndex ?? state.currentSectionIndex) + 1}: ${currentSection?.originalText ?? sectionTitle}'
                            : 'Teaching paused at: $sectionTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Dynamic Status Notice (Listening / Thinking / Answering)
          if (isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔴 ', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    'Listening...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE11D48), fontSize: 13.5),
                  ),
                ],
              ),
            )
          else if (isGenerating)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🧠 ', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    'Understanding...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 13.5),
                  ),
                ],
              ),
            )
          else if (isSpeakingAnswer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔊 ', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    'Teacher is answering...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13.5),
                  ),
                ],
              ),
            ),

          // Error / Permission Notice
          if (_statusNotice != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isPermissionError ? Colors.amber.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isPermissionError ? Colors.amber.shade300 : Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPermissionError ? Icons.mic_off : Icons.info_outline,
                        size: 18,
                        color: _isPermissionError ? Colors.amber.shade900 : Colors.blue.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusNotice!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isPermissionError ? Colors.amber.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isPermissionError) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () {
                            _textFocusNode.requestFocus();
                            setState(() => _statusNotice = null);
                          },
                          child: const Text('Type Doubt Instead', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _handleMicTap(state),
                          child: const Text('Try Again', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Chat Q&A View Area
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (activeQuestion != null) ...[
                  // Student Doubt Bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        activeQuestion,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (activeAnswer != null && activeAnswer.isNotEmpty) ...[
                  // Teacher Answer Bubble
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.school, size: 14, color: Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Teacher Explanation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            activeAnswer,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (!isGenerating && activeQuestion == null) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.record_voice_over_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Ask anything about this section',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the mic to speak or type your question below.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Action: Continue Lesson Button (Prominent when answer is given)
          if (activeAnswer != null && !isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Continue Lesson',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    state.continueFromDoubt();
                  },
                ),
              ),
            ),

          // Input Bar (Mic + Text + Send)
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Microphone Input Button
                GestureDetector(
                  onTap: isGenerating ? null : () => _handleMicTap(state),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isListening ? const Color(0xFFE11D48) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening ? Icons.stop : Icons.mic,
                      color: isListening ? Colors.white : const Color(0xFF1E293B),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Type your doubt here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _submitDoubt(state),
                  ),
                ),
                const SizedBox(width: 8),

                // Submit Button
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                  ),
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  onPressed: isGenerating ? null : () => _submitDoubt(state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
