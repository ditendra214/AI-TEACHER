import 'package:flutter/material.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/app_repository.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final AppRepository _repository = AppRepository();
  Map<String, dynamic> _stats = {};
  List<QuizResult> _quizHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() => _isLoading = true);
    final stats = await _repository.getProgressStatistics();
    final history = await _repository.getQuizResults();

    if (mounted) {
      setState(() {
        _stats = stats;
        _quizHistory = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Preparation Progress')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalTopics = _stats['total_topics'] as int? ?? 0;
    final completedTopics = _stats['completed_topics'] as int? ?? 0;
    final totalQuizzes = _stats['total_quizzes'] as int? ?? 0;
    final avgScore = (_stats['average_quiz_score'] as num?)?.toDouble() ?? 0.0;
    final totalDocs = _stats['total_documents'] as int? ?? 0;

    final double completionPct = totalTopics > 0 ? (completedTopics / totalTopics) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparation Progress'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgressData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Big Progress Circle Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: completionPct,
                            strokeWidth: 8,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${(completionPct * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Syllabus Coverage',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedTopics of $totalTopics Topics Done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            completedTopics == totalTopics && totalTopics > 0
                                ? '🎉 All topics revised!'
                                : 'Keep studying to finish your syllabus.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Quiz Attempts',
                      '$totalQuizzes',
                      Icons.quiz_outlined,
                      Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Avg Quiz Score',
                      '${avgScore.round()}%',
                      Icons.insights,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Study Materials',
                      '$totalDocs',
                      Icons.description_outlined,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Active Subjects',
                      '${_stats['total_subjects'] ?? 1}',
                      Icons.book_outlined,
                      Colors.deepOrange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Quiz History
              const Text(
                'Recent Quiz History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_quizHistory.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No quizzes completed yet. Take a quiz to track your score!',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                )
              else
                ..._quizHistory.take(5).map(
                  (res) {
                    final pct = res.percentage.round();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pct >= 60 ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            pct >= 60 ? Icons.check : Icons.close,
                            color: pct >= 60 ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Text(res.topicTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${res.date.day}/${res.date.month}/${res.date.year}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Text(
                          '${res.score} / ${res.totalQuestions} ($pct%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: pct >= 60 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
