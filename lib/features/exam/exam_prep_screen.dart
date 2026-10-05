import 'package:flutter/material.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, String>> _twoMarkQuestions = [
    {
      'question': '1. Define an algorithm and list Donald Knuth\'s five criteria.',
      'answer': 'Definition: An algorithm is a finite, ordered sequence of unambiguous instructions to solve a problem.\n\n5 Criteria:\n1. Input: Zero or more inputs.\n2. Output: At least one output.\n3. Definiteness: Clear, unambiguous instructions.\n4. Finiteness: Terminates in finite steps.\n5. Effectiveness: Feasible and computable basic operations.',
    },
    {
      'question': '2. Define Big O notation mathematically.',
      'answer': 'Definition: f(n) = O(g(n)) if and only if there exist positive constants c > 0 and n₀ ≥ 1 such that:\n0 ≤ f(n) ≤ c · g(n) for all n ≥ n₀.\n\nSignificance: Represents the asymptotic upper bound (worst-case running time).',
    },
    {
      'question': '3. Differentiate between Space Complexity and Auxiliary Space.',
      'answer': '• Space Complexity: Total memory used by the algorithm including input space + temporary variables + recursion stack.\n• Auxiliary Space: Only the extra or temporary space used by the algorithm excluding input size.',
    },
    {
      'question': '4. What is an in-place sorting algorithm?',
      'answer': 'An algorithm that sorts the input array without allocating extra auxiliary memory proportional to n. Its auxiliary space is O(1). Examples: Heapsort, Bubble Sort, Insertion Sort.',
    },
    {
      'question': '5. State the Master Theorem formula for divide-and-conquer recurrences.',
      'answer': 'For recurrences T(n) = a T(n/b) + f(n):\nCompare f(n) with n^(log_b a):\n1. If f(n) < n^(log_b a): T(n) = Θ(n^(log_b a))\n2. If f(n) = n^(log_b a): T(n) = Θ(n^(log_b a) log n)\n3. If f(n) > n^(log_b a): T(n) = Θ(f(n)).',
    },
  ];

  final List<Map<String, String>> _fiveMarkQuestions = [
    {
      'question': '1. Compare Divide-and-Conquer vs Dynamic Programming with examples.',
      'answer': '• Subproblems: Divide & Conquer handles independent non-overlapping subproblems; Dynamic Programming handles overlapping subproblems.\n• Efficiency: Divide & Conquer can recompute identical subproblems (e.g. naive Fibonacci); DP uses memoization/tabulation to solve each once.\n• Approach: D&C is typically top-down recursive; DP can be top-down memoized or bottom-up tabular.\n• Examples: Merge Sort / Binary Search (D&C) vs 0/1 Knapsack / Floyd-Warshall (DP).',
    },
    {
      'question': '2. Explain the hierarchy of time complexities with a neat growth diagram description.',
      'answer': 'Asymptotic Growth Ordering (Fastest to Slowest):\n1. O(1) Constant (Array index access)\n2. O(log n) Logarithmic (Binary Search)\n3. O(n) Linear (Linear Search)\n4. O(n log n) Linearithmic (Merge Sort, Quick Sort avg)\n5. O(n²) Quadratic (Bubble Sort, Selection Sort)\n6. O(n³) Cubic (Standard Matrix Multiplication)\n7. O(2ⁿ) Exponential (Tower of Hanoi)\n8. O(n!) Factorial (Traveling Salesperson Brute Force)\n\nExam Tip: Draw the X-axis as n, Y-axis as Time. O(1) is flat, O(log n) bends down, O(n) is diagonal 45°, O(n²) curves steeply upwards.',
    },
    {
      'question': '3. Explain Big-Omega (Ω) and Big-Theta (Θ) notations with formulas.',
      'answer': '1. Big-Omega (Ω) — Lower Bound:\nf(n) = Ω(g(n)) iff 0 ≤ c · g(n) ≤ f(n) for all n ≥ n₀.\nGuarantees the best-case execution floor.\n\n2. Big-Theta (Θ) — Tight Bound:\nf(n) = Θ(g(n)) iff c₁ · g(n) ≤ f(n) ≤ c₂ · g(n) for all n ≥ n₀.\nRepresents exact asymptotic rate of growth. Holds iff f(n) = O(g(n)) and f(n) = Ω(g(n)).',
    },
  ];

  final List<Map<String, String>> _tenMarkQuestions = [
    {
      'question': '1. Comprehensive Analysis of Merge Sort: Algorithm, Trace, Recurrence, and Space-Time Complexity.',
      'answer': '1. Introduction: Merge Sort is a comparison-based divide-and-conquer sorting algorithm.\n\n2. Algorithm Steps:\n• Divide: Split array into two halves at mid = (low + high) / 2.\n• Conquer: Recursively sort left and right subarrays.\n• Combine: Merge two sorted subarrays using two pointers into auxiliary array.\n\n3. Recurrence Relation:\nT(n) = 2T(n/2) + cn for n > 1, T(1) = 1.\nBy Master Theorem (a=2, b=2, k=1): T(n) = Θ(n log n) in Best, Average, and Worst cases.\n\n4. Space Complexity:\nAuxiliary Space = O(n) due to temporary buffer arrays.\n\n5. Advantages: Stable sort, predictable Θ(n log n), excellent for linked lists.\nDisadvantages: Requires O(n) extra RAM memory.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Preparation'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1D4ED8),
          indicatorColor: const Color(0xFF1D4ED8),
          tabs: const [
            Tab(text: '2-Mark Qs'),
            Tab(text: '5-Mark Qs'),
            Tab(text: '10-Mark Qs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionList(_twoMarkQuestions, '2 Marks (Short Answers)'),
          _buildQuestionList(_fiveMarkQuestions, '5 Marks (Medium Answers)'),
          _buildQuestionList(_tenMarkQuestions, '10 Marks (Long Answers)'),
        ],
      ),
    );
  }

  Widget _buildQuestionList(List<Map<String, String>> questions, String badge) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final item = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              item['question']!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(badge, style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
            ),
            childrenPadding: const EdgeInsets.all(16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: SelectableText(
                  item['answer']!,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
