import 'package:flutter/material.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/app_repository.dart';

class QuizScreen extends StatefulWidget {
  final int? topicId;
  final String? topicTitle;

  const QuizScreen({super.key, this.topicId, this.topicTitle});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AppRepository _repository = AppRepository();
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _hasAnsweredCurrent = false;
  int _score = 0;
  bool _quizFinished = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    final list = await _repository.getQuizQuestions(topicId: widget.topicId);
    if (mounted) {
      setState(() {
        _questions = list;
        _isLoading = false;
      });
    }
  }

  void _selectOption(int index) {
    if (_hasAnsweredCurrent) return;

    setState(() {
      _selectedOptionIndex = index;
      _hasAnsweredCurrent = true;
      if (index == _questions[_currentIndex].correctOptionIndex) {
        _score++;
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _hasAnsweredCurrent = false;
      });
    } else {
      // Quiz finished - save score
      setState(() => _quizFinished = true);
      final result = QuizResult(
        topicTitle: widget.topicTitle ?? 'Algorithms Exam Quiz',
        score: _score,
        totalQuestions: _questions.length,
        date: DateTime.now(),
      );
      await _repository.saveQuizResult(result);
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _hasAnsweredCurrent = false;
      _score = 0;
      _quizFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Quiz')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No quiz questions available yet for this topic.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_quizFinished) {
      return _buildResultsScreen(context);
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
      ),
      body: Column(
        children: [
          // Progress Header
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF1D4ED8),
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.topicTitle ?? 'Exam Knowledge Check',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Score: $_score / ${_questions.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Question Card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      q.question,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Options
                  ...List.generate(q.options.length, (idx) {
                    return _buildOptionTile(q, idx);
                  }),

                  const SizedBox(height: 16),

                  // Explanation Card after answering
                  if (_hasAnsweredCurrent) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade800, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Teacher Explanation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            q.explanation,
                            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasAnsweredCurrent ? _nextQuestion : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_currentIndex < _questions.length - 1 ? 'Next Question' : 'View Results'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(QuizQuestion q, int index) {
    Color? borderColor = Colors.grey.shade300;
    Color? bgColor = Colors.white;
    IconData? trailingIcon;
    Color? iconColor;

    if (_hasAnsweredCurrent) {
      if (index == q.correctOptionIndex) {
        borderColor = Colors.green;
        bgColor = Colors.green.shade50;
        trailingIcon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (index == _selectedOptionIndex) {
        borderColor = Colors.red;
        bgColor = Colors.red.shade50;
        trailingIcon = Icons.cancel;
        iconColor = Colors.red;
      }
    } else if (_selectedOptionIndex == index) {
      borderColor = const Color(0xFF1D4ED8);
      bgColor = Colors.blue.shade50;
    }

    final optionLabels = ['A', 'B', 'C', 'D'];
    final label = index < optionLabels.length ? optionLabels[index] : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _selectOption(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.options[index],
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
              ),
              if (trailingIcon != null) Icon(trailingIcon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(BuildContext context) {
    final pct = (_score / _questions.length) * 100;
    final isPassed = pct >= 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPassed ? Icons.emoji_events : Icons.refresh,
                size: 72,
                color: isPassed ? Colors.amber.shade700 : Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                isPassed ? 'Great Performance! 🎉' : 'Needs Practice! 📚',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_score out of ${_questions.length} (${pct.round()}%)',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _resultStatRow('Total Questions', '${_questions.length}'),
                      const Divider(),
                      _resultStatRow('Correct Answers', '$_score'),
                      const Divider(),
                      _resultStatRow('Accuracy', '${pct.round()}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _restartQuiz,
                    icon: const Icon(Icons.replay),
                    label: const Text('Retry Quiz'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Course'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
