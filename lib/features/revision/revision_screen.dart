import 'package:flutter/material.dart';

class RevisionScreen extends StatelessWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Revision'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last-Minute Exam Cheat Sheet ⚡',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Quick formula reference, common traps, and definitions to review before the exam.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 1: Core Complexity Hierarchy
            _buildRevisionCard(
              title: '1. Asymptotic Complexity Hierarchy',
              subtitle: 'From Fastest to Slowest growth rate:',
              icon: Icons.speed,
              color: Colors.blue,
              items: [
                'O(1) — Constant (Fastest)',
                'O(log n) — Logarithmic (Binary Search, Balanced BST)',
                'O(n) — Linear (Linear Search, Single loop)',
                'O(n log n) — Linearithmic (Merge Sort, Heap Sort)',
                'O(n²) — Quadratic (Nested loops, Bubble Sort)',
                'O(2ⁿ) — Exponential (Subsets, Hanoi)',
                'O(n!) — Factorial (Permutations, TSP Brute Force)',
              ],
            ),
            const SizedBox(height: 14),

            // Card 2: Essential Formulas
            _buildRevisionCard(
              title: '2. Mathematical Bounds & Formulas',
              subtitle: 'Formulas examiners check strictly:',
              icon: Icons.functions,
              color: Colors.purple,
              items: [
                'Big O: 0 ≤ f(n) ≤ c · g(n) for all n ≥ n₀',
                'Big Omega: 0 ≤ c · g(n) ≤ f(n) for all n ≥ n₀',
                'Big Theta: c₁ · g(n) ≤ f(n) ≤ c₂ · g(n) for all n ≥ n₀',
                'Sum of first n numbers: n(n+1)/2 = O(n²)',
                'Tree height with n nodes: h = ⌊log₂ n⌋',
              ],
            ),
            const SizedBox(height: 14),

            // Card 3: Common Student Mistakes to Avoid
            _buildRevisionCard(
              title: '3. Common Exam Mistakes to Avoid ⚠️',
              subtitle: 'Lose marks if forgotten:',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              items: [
                'Forgetting the constants (c > 0, n₀ ≥ 1) in asymptotic definitions.',
                'Saying QuickSort worst case is O(n log n) — it is actually O(n²) if pivot is worst!',
                'Confusing Space Complexity with Auxiliary Space (Auxiliary excludes input size).',
                'Claiming Greedy always gives optimal answer (Greedy fails for 0/1 Knapsack!).',
              ],
            ),
            const SizedBox(height: 14),

            // Card 4: Telugu + English Quick Intuition
            _buildRevisionCard(
              title: '4. Telugu + English Rapid Recall 💡',
              subtitle: 'Simple intuition points in Tanglish:',
              icon: Icons.translate,
              color: Colors.teal,
              items: [
                'Big O: Worst-case ceiling — deeni kante ekkuva time pattadu.',
                'Omega: Best-case floor — intha kante thakkuva time pattadu.',
                'Theta: Exact time — both upper and lower match ayinappudu.',
                'Greedy: Appatiki edhi best choice anipisthe adi choose cheskovadam.',
                'Dynamic Programming: Same calculation malli malli cheyakunda save (memoize) cheskovadam.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
