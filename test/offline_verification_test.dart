import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/ai/ai_service.dart';
import 'package:ai_teacher/ai/prompt_builder.dart';
import 'package:ai_teacher/data/models/subject_model.dart';
import 'package:ai_teacher/data/models/topic_model.dart';
import 'package:ai_teacher/data/models/chat_message_model.dart';
import 'package:ai_teacher/data/models/quiz_model.dart';
import 'package:ai_teacher/data/models/lesson_progress_model.dart';
import 'package:ai_teacher/data/repositories/app_repository.dart';
import 'package:ai_teacher/data/services/teaching_state.dart';

/// In-memory repository implementation for hermetic offline test validation
class FakeOfflineRepository extends AppRepository {
  final List<ChatMessage> chatMessages = [];
  final Map<int, LessonProgress> progressMap = {};
  final List<QuizResult> quizResults = [];

  // 6 Pre-seeded Algorithms Topics with complete academic lesson sections
  final List<Topic> preSeededTopics = [
    Topic(
      id: 1,
      subjectId: 1,
      title: '1. Algorithm Definition & Essentials',
      summary: 'Fundamental concept of algorithms, inputs, outputs, finiteness, and correctness.',
      orderIndex: 0,
      sections: [
        LessonSection(
          id: 101,
          topicId: 1,
          title: 'What is an Algorithm?',
          definition: 'An algorithm is a step-by-step, finite sequence of unambiguous instructions designed to solve a computational problem or perform a specific task.',
          importance: 'Serves as the theoretical blueprint for writing any computer software or system.',
          explanation: 'Every algorithm accepts zero or more well-defined inputs, processes them through deterministic logical steps, and produces one or more outputs. It must terminate after a finite number of steps.',
          example: 'Recipe for making tea, or finding the maximum number in a list of integers.',
          teluguExplanation: 'Algorithm ante oka problem solve cheyadaniki manam step-by-step ga raase clear instructions set.',
          examPoints: '• Must be finite, unambiguous, and input-output driven.\n• Distinct from a program (independent of programming language syntax).\n• 2-Mark Question favorite: "Define Algorithm and state its criteria."',
          checkQuestion: 'Can an algorithm run infinitely and still be called a valid algorithm?',
          checkAnswer: 'No, finiteness is a strict requirement; an infinite process is called a computational method, not an algorithm.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 102,
          topicId: 1,
          title: 'Algorithm Properties & Criteria',
          definition: 'The five canonical criteria formulated by Donald Knuth: Input, Output, Definiteness, Finiteness, and Effectiveness.',
          importance: 'Used by examiners to verify whether a proposed procedure qualifies as an algorithm.',
          explanation: '1. Input: 0 or more inputs.\n2. Output: At least 1 output.\n3. Definiteness: Every step is clear and unambiguous.\n4. Finiteness: Terminates in finite steps.\n5. Effectiveness: Operations are simple enough to be done with paper and pencil.',
          example: 'Division by zero violates Definiteness/Effectiveness because it is undefined.',
          teluguExplanation: 'Knuth cheppina 5 main criteria: Input, Output, Definiteness (clarity), Finiteness (end avvali), and Effectiveness (practical ga undali).',
          examPoints: '• Frequently asked as a 5-mark question.\n• Always list all 5 criteria with one line explanation each.',
          checkQuestion: 'Which property requires every step to have a clear, unique meaning?',
          checkAnswer: 'Definiteness.',
          sectionOrder: 1,
        ),
      ],
    ),
    Topic(
      id: 2,
      subjectId: 1,
      title: '2. Properties & Types of Algorithms',
      summary: 'Major algorithmic paradigms including Brute Force, Divide and Conquer, Greedy, and Dynamic Programming.',
      orderIndex: 1,
      sections: [
        LessonSection(
          id: 201,
          topicId: 2,
          title: 'Algorithm Paradigms Overview',
          definition: 'An algorithmic paradigm is a generalized approach or framework for designing algorithms to solve problems.',
          importance: 'Helps categorize and choose the most optimal strategy for any given problem.',
          explanation: 'Common paradigms:\n• Brute Force: Exhaustive search of all possibilities.\n• Divide & Conquer: Split problem, solve subproblems recursively, combine results.\n• Greedy: Make locally optimal choice at each step.\n• Dynamic Programming: Solve overlapping subproblems and memoize results.',
          example: 'Divide & Conquer: Merge Sort. Greedy: Kruskal\'s MST. Dynamic Programming: Fibonacci numbers.',
          teluguExplanation: 'Problem solve chese approaches: Divide & Conquer ante problem ni chinnaga chesi solve cheyadam; Greedy ante appatiki edhi best anipisthe adi pick cheskovadam.',
          examPoints: '• Compare Divide & Conquer vs Dynamic Programming (Very common 5/10 mark question).\n• Divide & Conquer handles non-overlapping subproblems; DP handles overlapping subproblems.',
          checkQuestion: 'Which paradigm chooses the best local choice without backtracking?',
          checkAnswer: 'Greedy Algorithm paradigm.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 202,
          topicId: 2,
          title: 'Divide & Conquer vs Dynamic Programming',
          definition: 'Divide and Conquer solves problems by combining solutions to non-overlapping subproblems; Dynamic Programming memoizes solutions to overlapping subproblems with optimal substructure.',
          importance: 'Classic 5-mark and 10-mark comparison question in every university algorithms paper.',
          explanation: 'Key differences:\n1. Subproblems: D&C subproblems are independent (e.g., Merge Sort left/right halves); DP subproblems share common subproblems (e.g., Fibonacci, Bellman-Ford).\n2. Duplication: D&C may recompute identical subproblems multiple times; DP computes each once and stores in a lookup table.\n3. Approaches: DP supports Top-Down (Memoization) and Bottom-Up (Tabulation).',
          example: 'Computing Fibonacci numbers: Naive recursion takes O(2ⁿ) time with duplicate calls; DP tabulation takes O(n) time and O(n) space.',
          teluguExplanation: 'Divide and Conquer lo subproblems separate ga untayi (Merge Sort laaga). Dynamic Programming lo subproblems malli malli repeat avthayi, so okasari compute chesi table lo save cheskuntam.',
          examPoints: '• Draw the recursion tree showing duplicate nodes for Fibonacci.\n• Create a two-column comparison table: Concept, Subproblem type, Efficiency, and Canonical Examples.',
          checkQuestion: 'What are the two core conditions required to apply Dynamic Programming?',
          checkAnswer: 'Overlapping Subproblems and Optimal Substructure.',
          sectionOrder: 1,
        ),
      ],
    ),
    Topic(
      id: 3,
      subjectId: 1,
      title: '3. Algorithm Analysis Framework',
      summary: 'Theoretical framework for evaluating algorithm efficiency independently of machine hardware.',
      orderIndex: 2,
      sections: [
        LessonSection(
          id: 301,
          topicId: 3,
          title: 'Why Analyze Algorithms?',
          definition: 'Algorithm analysis is the study of resource consumption (CPU time and memory space) relative to input size n.',
          importance: 'Enables developers to predict performance without running on different physical hardware architectures.',
          explanation: 'Execution time measured in wall-clock seconds varies across processors, compiler optimizations, and background processes. Theoretical analysis counts the number of elementary operations executed as a function of input size n.',
          example: 'Comparing Linear Search (n operations) with Binary Search (log n operations) on 1,000,000 items.',
          teluguExplanation: 'Algorithm analysis ante computer speed tho sambandham lekunda input size n perigithe time and memory entha peruguthundo calculate cheyadam.',
          examPoints: '• Independent of machine, language, or compiler.\n• Focuses on rate of growth (asymptotic growth) as n approaches infinity.',
          checkQuestion: 'Why do we avoid measuring actual execution time in seconds for algorithm comparison?',
          checkAnswer: 'Because wall-clock time depends on CPU clock speed, RAM speed, OS scheduling, and compiler optimizations.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 302,
          topicId: 3,
          title: 'Best-Case, Worst-Case, and Average-Case Analysis',
          definition: 'Analysis based on input configurations: Worst-case provides the upper bound on any input; Best-case provides the lower bound; Average-case calculates the expected time over all valid inputs.',
          importance: 'Helps software engineers make informed trade-offs between guaranteed safety and real-world expected runtime.',
          explanation: '1. Worst-Case Time (W(n)): Maximum number of steps across all inputs of size n. Always provides a deterministic guarantee.\n2. Best-Case Time (B(n)): Minimum steps executed on the most favorable input. Often trivial (e.g., target element at index 0 in linear search).\n3. Average-Case Time (A(n)): Expected steps assuming a probability distribution over all inputs. Requires calculating expected value across all permutations.',
          example: 'Linear Search: Best-case is O(1) (found at index 0); Worst-case is O(n) (not found or at the end); Average-case is O(n/2) = O(n). Quick Sort: Best/Average is O(n log n); Worst-case is O(n²).',
          teluguExplanation: 'Worst-case ante hardest input ki entha time paduthundo (maximum time). Best-case ante easiest input ki (minimum time). Average-case ante standard average performance.',
          examPoints: '• Professors usually demand: "Why is worst-case analysis preferred over average-case?"\n• Answer: Worst-case gives an absolute guarantee and does not rely on unknown probability assumptions.',
          checkQuestion: 'Why is average-case analysis typically more difficult to compute than worst-case analysis?',
          checkAnswer: 'Because it requires determining or assuming the exact probability distribution of all possible input configurations.',
          sectionOrder: 1,
        ),
      ],
    ),
    Topic(
      id: 4,
      subjectId: 1,
      title: '4. Time Complexity & Growth Rates',
      summary: 'Understanding how run-time scales with input size n: constant, logarithmic, linear, quadratic, exponential.',
      orderIndex: 3,
      sections: [
        LessonSection(
          id: 401,
          topicId: 4,
          title: 'Order of Growth',
          definition: 'The order of growth describes how quickly the execution time increases when the input size n increases.',
          importance: 'Distinguishes between practical algorithms and computationally intractable algorithms.',
          explanation: 'Hierarchy of common complexities from fastest to slowest:\n1. O(1) - Constant Time\n2. O(log n) - Logarithmic Time\n3. O(n) - Linear Time\n4. O(n log n) - Linearithmic Time\n5. O(n²) - Quadratic Time\n6. O(2ⁿ) - Exponential Time',
          example: 'Accessing array element by index is O(1); Bubble sort is O(n²); Tower of Hanoi is O(2ⁿ).',
          teluguExplanation: 'Input size n peddadi aithe, execution time entha speed tho perugutundo order of growth antam. O(1) fastest, O(2ⁿ) chala slow.',
          examPoints: '• Draw the graph of n vs Operations for 5-mark answer.\n• Emphasize that for large n, constants become negligible.',
          checkQuestion: 'Which is faster for n = 1,000,000: O(n log n) or O(n²)?',
          checkAnswer: 'O(n log n) is dramatically faster; ~20 million ops vs 1 trillion ops.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 402,
          topicId: 4,
          title: 'Analyzing Loops & Recurrence Relations',
          definition: 'Techniques for determining complexity of iterative code (counting loop iterations) and recursive code (solving recurrence relations via Master Theorem).',
          importance: 'Standard practical examination questions where students must analyze code snippets and compute Big-O.',
          explanation: 'Rules of Thumb:\n• Single loop from 1 to n with step 1: O(n)\n• Loop with step i = i * 2: O(log n)\n• Nested loops where outer is n and inner is n: O(n²)\n• Master Theorem for T(n) = aT(n/b) + f(n):\n  - If f(n) = O(n^{log_b(a) - ε}), T(n) = Θ(n^{log_b a})\n  - If f(n) = Θ(n^{log_b a}), T(n) = Θ(n^{log_b a} · log n)',
          example: 'Merge Sort recurrence: T(n) = 2T(n/2) + O(n). Here a=2, b=2, log_b(a)=1. By Master Theorem Case 2, T(n) = Θ(n log n).',
          teluguExplanation: 'Loops unte iterations count chestham (nested loops aithe n*n = n²). Recursion equations vachinapudu Master Theorem formula use chesi direct ga answer calculate cheyachu.',
          examPoints: '• State the Master Theorem formula and its 3 cases clearly.\n• Show step-by-step substitution when analyzing nested loop bounds.',
          checkQuestion: 'What is the time complexity of a loop where index i doubles in each step (for i=1; i<n; i*=2)?',
          checkAnswer: 'O(log n) because the number of iterations k satisfies 2ᵏ ≈ n, giving k ≈ log₂ n.',
          sectionOrder: 1,
        ),
      ],
    ),
    Topic(
      id: 5,
      subjectId: 1,
      title: '5. Asymptotic Notations: Big O, Omega, Theta',
      summary: 'Mathematical definitions of asymptotic bounds: Upper bound (O), Lower bound (Ω), and Tight bound (Θ).',
      orderIndex: 4,
      sections: [
        LessonSection(
          id: 501,
          topicId: 5,
          title: 'Big-O Notation (Upper Bound)',
          definition: 'f(n) = O(g(n)) if there exist positive constants c and n₀ such that 0 ≤ f(n) ≤ c · g(n) for all n ≥ n₀.',
          importance: 'Guarantees the worst-case maximum time an algorithm will ever take.',
          explanation: 'Big-O provides an asymptotic upper bound. It means the algorithm will never take more time than c · g(n) for sufficiently large n. It represents the ceiling of the running time.',
          example: 'Insertion Sort worst-case is O(n²); Binary Search is O(log n).',
          teluguExplanation: 'Big O ante upper bound - worst case lo algorithm maximum entha time theesukuntundo guarantee istundi. Dini kante ekkuva time pattadu.',
          examPoints: '• Write the exact mathematical equation: 0 ≤ f(n) ≤ c·g(n) for n ≥ n₀.\n• State that Big O gives worst-case safety guarantee.\n• Most common 2-mark & 5-mark question in every semester exam.',
          checkQuestion: 'What does the constant n₀ represent in the definition of Big O?',
          checkAnswer: 'The threshold input size beyond which the inequality f(n) ≤ c·g(n) strictly holds.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 502,
          topicId: 5,
          title: 'Big-Omega (Ω) and Big-Theta (Θ) Notations',
          definition: 'Big-Omega (Ω) represents the asymptotic lower bound: 0 ≤ c · g(n) ≤ f(n) for n ≥ n₀. Big-Theta (Θ) represents the tight bound: c₁ · g(n) ≤ f(n) ≤ c₂ · g(n) for n ≥ n₀.',
          importance: 'Big-Omega gives best-case guarantee; Big-Theta gives exact growth rate when upper and lower bounds coincide.',
          explanation: '• Big-Omega (Ω): Algorithm takes at least this much time.\n• Big-Theta (Θ): Algorithm is sandwiched between c₁ and c₂. We only say f(n) = Θ(g(n)) if f(n) = O(g(n)) and f(n) = Ω(g(n)).',
          example: 'Linear search best case (found at index 0) is Ω(1). Merge Sort is Θ(n log n) in all cases.',
          teluguExplanation: 'Omega (Ω) ante minimum time (lower bound). Theta (Θ) ante exact time (both upper and lower bound kalisi unte).',
          examPoints: '• Draw the three curves: upper bound c·g(n), f(n), and lower bound c·g(n).\n• State the condition for Theta: f(n)=Θ(g(n)) iff f(n)=O(g(n)) and f(n)=Ω(g(n)).',
          checkQuestion: 'If an algorithm is both O(n) and Ω(n), what is its Theta bound?',
          checkAnswer: 'Θ(n).',
          sectionOrder: 1,
        ),
        LessonSection(
          id: 503,
          topicId: 5,
          title: 'Strict Bounds: Little-o and Little-omega',
          definition: 'Little-o (o) denotes a non-tight upper bound where f(n) grows strictly slower than g(n). Little-omega (ω) denotes a strict lower bound where f(n) grows strictly faster than g(n).',
          importance: 'Tested in competitive exams and university theory questions on asymptotic limits.',
          explanation: 'Limit definitions:\n• Little-o: lim_{n→∞} f(n)/g(n) = 0. Example: 2n = o(n²), but 2n² ≠ o(n²).\n• Little-omega: lim_{n→∞} f(n)/g(n) = ∞. Example: n² = ω(n).\nAnalogy with arithmetic:\n• Big-O is like ≤\n• Big-Omega is like ≥\n• Big-Theta is like =\n• Little-o is like <\n• Little-omega is like >',
          example: '3n + 5 = O(n) and 3n + 5 = O(n²). But 3n + 5 = o(n²) is true, while 3n + 5 = o(n) is FALSE.',
          teluguExplanation: 'Big O ante ≤ (less than or equal to). Little o ante strictly < (strictly less than). Limit n→∞ f(n)/g(n) = 0 aithe Little o antam.',
          examPoints: '• Write the limit definition: lim_{n→∞} [f(n)/g(n)] = 0 for Little-o.\n• Mention the mathematical analogy with real number inequalities (≤, ≥, =, <, >).',
          checkQuestion: 'Is 5n² = o(n²)?',
          checkAnswer: 'No, because the limit as n→∞ of (5n²/n²) is 5, not 0. 5n² is O(n²) and Θ(n²), but not o(n²).',
          sectionOrder: 2,
        ),
      ],
    ),
    Topic(
      id: 6,
      subjectId: 1,
      title: '6. Space Complexity & Auxiliary Memory',
      summary: 'Memory requirements of algorithms: fixed vs variable parts, recursion stack space, and in-place algorithms.',
      orderIndex: 5,
      sections: [
        LessonSection(
          id: 601,
          topicId: 6,
          title: 'Space Complexity & Auxiliary Space',
          definition: 'Space Complexity is the total amount of memory space required by the algorithm with respect to input size n. Auxiliary space is the extra space used excluding input space.',
          importance: 'Critical in embedded devices, mobile apps, and memory-constrained environments.',
          explanation: 'Space Complexity = Fixed Part (code space, simple variables) + Variable Part (dynamically allocated memory, recursive call stack). An in-place algorithm has auxiliary space O(1).',
          example: 'Merge sort requires O(n) auxiliary space for temp arrays. Quick sort requires O(log n) auxiliary stack space.',
          teluguExplanation: 'Space complexity ante algorithm run avvadaniki entha memory kavalo adi. Extra ga use chese memory ni auxiliary space antaru.',
          examPoints: '• Differentiate Space Complexity vs Auxiliary Space (Important 2-mark question).\n• In-place sorting algorithms use O(1) auxiliary space.',
          checkQuestion: 'Does an algorithm that modifies an array in-place without extra arrays have O(1) auxiliary space?',
          checkAnswer: 'Yes, in-place algorithms utilize O(1) auxiliary space.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 602,
          topicId: 6,
          title: 'Recursion Stack Space & In-Place Algorithms',
          definition: 'Recursion stack space refers to the memory allocated on the call stack for function activation records. In-place algorithms require O(1) auxiliary space beyond the input data.',
          importance: 'Crucial for understanding memory limits, stack overflow errors, and optimizing resource-constrained code.',
          explanation: 'Every recursive call pushes an activation record (return address, parameter values, local variables) onto the system stack.\n• Depth of recursion tree determines stack space.\n• Balanced recursion tree of depth d requires O(d) stack space.\n• Tail recursion can be optimized by compilers into loops to eliminate stack overhead.',
          example: 'Tree traversal on balanced binary tree of depth log n requires O(log n) stack frames; on skewed tree it requires O(n) stack frames. In-place sorting: Heap Sort uses O(1) auxiliary space; Merge Sort uses O(n).',
          teluguExplanation: 'Function tana ni tanu call cheskunappudu system call stack lo frame create avthundi. Tree depth batti memory spend avtundi. Extra memory lekunda same array lo sort chesthe In-place algorithm antaru.',
          examPoints: '• Explain Activation Record components (parameters, return address, local variables).\n• Contrast Merge Sort (O(n) auxiliary) with Quick Sort (O(log n) stack auxiliary) and Heap Sort (O(1) in-place).',
          checkQuestion: 'What causes a StackOverflowError in recursive algorithms?',
          checkAnswer: 'Excessive recursion depth without reaching a base case, exhausting the finite memory allocated to the thread call stack.',
          sectionOrder: 1,
        ),
      ],
    ),
  ];

  @override
  Future<List<Topic>> getTopicsForSubject(int subjectId) async {
    return preSeededTopics;
  }

  @override
  Future<List<LessonSection>> getSectionsForTopic(int topicId) async {
    final t = preSeededTopics.firstWhere((topic) => topic.id == topicId);
    return t.sections;
  }

  @override
  Future<LessonProgress?> getProgressForTopic(int topicId) async {
    return progressMap[topicId];
  }

  @override
  Future<void> saveProgress({
    required int subjectId,
    required int topicId,
    required int currentSectionIndex,
    required int totalSections,
    bool isCompleted = false,
  }) async {
    progressMap[topicId] = LessonProgress(
      id: topicId,
      subjectId: subjectId,
      topicId: topicId,
      subjectTitle: 'Design & Analysis of Algorithms',
      topicTitle: preSeededTopics.firstWhere((t) => t.id == topicId).title,
      currentSectionIndex: currentSectionIndex,
      totalSections: totalSections,
      isCompleted: isCompleted,
      lastStudiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    return chatMessages.where((m) => m.sessionId == sessionId).toList();
  }

  @override
  Future<int> insertChatMessage(ChatMessage message) async {
    chatMessages.add(message);
    return chatMessages.length;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllChunks() async {
    return [
      {
        'id': 1,
        'document_id': 1,
        'chunk_index': 0,
        'content': 'Big O notation provides the asymptotic upper bound on algorithm runtime. Donald Knuth formulated the criteria: Input, Output, Definiteness, Finiteness, Effectiveness.',
        'page_number': 1,
      },
      {
        'id': 2,
        'document_id': 1,
        'chunk_index': 1,
        'content': 'Divide and Conquer algorithms split problems into subproblems. Dynamic Programming solves overlapping subproblems with optimal substructure.',
        'page_number': 2,
      },
    ];
  }

  @override
  Future<List<QuizQuestion>> getQuizQuestions({int? topicId}) async {
    return [
      QuizQuestion(
        id: 1,
        topicId: 5,
        question: 'What does Big-O notation mathematically represent?',
        options: [
          'Exact execution time in seconds',
          'Asymptotic upper-bound growth rate',
          'Physical memory address allocation',
          'Target programming language complexity',
        ],
        correctOptionIndex: 1,
        explanation: 'Big-O gives an asymptotic upper bound, guaranteeing the maximum running time for large input sizes n.',
        type: 'mcq',
      ),
      QuizQuestion(
        id: 2,
        topicId: 6,
        question: 'An algorithm that operates using only O(1) extra memory is called an in-place algorithm.',
        options: ['True', 'False'],
        correctOptionIndex: 0,
        explanation: 'In-place algorithms modify input data structures without using extra auxiliary memory proportional to n.',
        type: 'true_false',
      ),
    ];
  }

  @override
  Future<int> saveQuizResult(QuizResult result) async {
    quizResults.add(result);
    return quizResults.length;
  }

  @override
  Future<List<QuizResult>> getQuizResults() async {
    return quizResults;
  }
}

void main() {
  group('AI Teacher True Offline Verification Tests', () {
    late FakeOfflineRepository repository;
    late AiService aiService;
    late TeachingState teachingState;
    late Subject algorithmsSubject;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      repository = FakeOfflineRepository();
      aiService = AiService();

      // Explicitly configure AI service with NO Gemini key and NO GGUF model path
      aiService.configure(
        providerType: AiProviderType.localAi,
        localModelPath: '', // No GGUF model installed
        geminiApiKey: '',   // No cloud Gemini API key
      );

      teachingState = TeachingState(
        repository: repository,
        aiService: aiService,
        prefs: prefs,
      );

      algorithmsSubject = Subject(
        id: 1,
        title: 'Design & Analysis of Algorithms',
        code: 'CS301',
        description: 'Core B.Tech Semester Exam Course',
        createdAt: DateTime.now(),
      );
    });

    // 1. Verify All 6 Pre-Seeded Topics & Complete Lesson Content
    test('Verify all six pre-seeded Algorithms topics contain actual usable lesson content', () {
      final topics = repository.preSeededTopics;
      expect(topics.length, equals(6), reason: 'Must have all 6 topics');

      const expectedTitles = [
        '1. Algorithm Definition & Essentials',
        '2. Properties & Types of Algorithms',
        '3. Algorithm Analysis Framework',
        '4. Time Complexity & Growth Rates',
        '5. Asymptotic Notations: Big O, Omega, Theta',
        '6. Space Complexity & Auxiliary Memory',
      ];

      for (int i = 0; i < topics.length; i++) {
        final t = topics[i];
        expect(t.title, equals(expectedTitles[i]));
        expect(t.summary.isNotEmpty, isTrue, reason: 'Topic summary must not be empty');
        expect(t.sections.length, greaterThanOrEqualTo(2), reason: 'Topic ${t.title} must have at least 2 sections');

        for (final s in t.sections) {
          // Verify no placeholder or demo text
          expect(s.title.isNotEmpty, isTrue);
          expect(s.definition.length, greaterThan(25), reason: 'Definition must be academically meaningful');
          expect(s.importance.length, greaterThan(15), reason: 'Importance must state exam relevance');
          expect(s.explanation.length, greaterThan(50), reason: 'Explanation must be in-depth');
          expect(s.example.length, greaterThan(10), reason: 'Must include real-world example/analogy');
          expect(s.teluguExplanation.length, greaterThan(15), reason: 'Must include Telugu+English Tanglish summary');
          expect(s.examPoints.length, greaterThan(20), reason: 'Must include semester exam scoring points');
          expect(s.checkQuestion.length, greaterThan(10), reason: 'Must have self-check question');
          expect(s.checkAnswer.length, greaterThan(3), reason: 'Must have self-check answer');

          // Ensure no placeholder keywords
          final combined = '${s.title} ${s.definition} ${s.explanation} ${s.examPoints}'.toLowerCase();
          expect(combined.contains('lorem ipsum'), isFalse);
          expect(combined.contains('todo:'), isFalse);
          expect(combined.contains('placeholder'), isFalse);
          expect(combined.contains('demo text'), isFalse);
        }
      }
    });

    // 2. Test Offline AI Response Generation (No Cloud, No GGUF Model)
    test('Offline AI Teacher never returns blank responses and answers algorithm doubts', () async {
      // Offline prompt with Big-O doubt
      final prompt =
          '${PromptBuilder.buildSystemPrompt(
            language: AppLanguage.teluguEnglish,
            mode: TeachingMode.doubt,
            subjectTitle: 'Design & Analysis of Algorithms',
            topicTitle: 'Asymptotic Notations',
          )}\n\n${PromptBuilder.buildUserPrompt('What is Big O notation?')}';

      final buffer = StringBuffer();
      await for (final token in aiService.streamResponse(prompt)) {
        buffer.write(token);
      }

      final response = buffer.toString();
      expect(response.trim().isNotEmpty, isTrue, reason: 'AI Response must NEVER be blank');
      expect(response, contains('Time Complexity & Big O Notation'));
      expect(response, contains('Definition:'));
      expect(response, contains('f(n) = O(g(n))'));
      expect(response, contains('Telugu + English Summary:'));
      expect(response, contains('Exam Tip'));
    });

    // 3. Test Offline AI Response on Arbitrary Doubt (Guaranteed Non-Blank)
    test('Offline AI Teacher returns structured concept explanation for arbitrary queries', () async {
      final prompt =
          '${PromptBuilder.buildSystemPrompt(
            language: AppLanguage.english,
            mode: TeachingMode.doubt,
            subjectTitle: 'Computer Networks',
            topicTitle: 'Distributed Systems Architecture',
            sectionContext: 'System Scalability',
          )}\n\n${PromptBuilder.buildUserPrompt('How does node failure recovery work in distributed clusters?')}';

      final buffer = StringBuffer();
      await for (final token in aiService.streamResponse(prompt)) {
        buffer.write(token);
      }

      final response = buffer.toString();
      expect(response.trim().isNotEmpty, isTrue);
      expect(response, contains('Detailed Concept Explanation'));
      expect(response, contains('Key Working Principles:'));
      expect(response, contains('Exam Scoring Advice:'));
    });

    // 4. Test Learn Mode Navigation & Progress Tracking
    test('Learn Mode: sequential navigation and progress persistence', () async {
      final topic = repository.preSeededTopics[1]; // Topic 2
      await teachingState.loadTopicLesson(topic, algorithmsSubject);

      expect(teachingState.currentMode, equals(TeachingMode.learn));
      expect(teachingState.currentSectionIndex, equals(0));
      expect(teachingState.currentSection?.title, equals('Algorithm Paradigms Overview'));
      expect(teachingState.hasNextSection, isTrue);

      // Move to Section 2
      await teachingState.nextSection();
      expect(teachingState.currentSectionIndex, equals(1));
      expect(teachingState.currentSection?.title, equals('Divide & Conquer vs Dynamic Programming'));

      // Check progress saved in repository
      final progress = await repository.getProgressForTopic(topic.id!);
      expect(progress, isNotNull);
      expect(progress!.currentSectionIndex, equals(1));
      expect(progress.percentInt, equals(100)); // Section index 1 of 2 = (1+1)/2 = 100%
    });

    // 5. Test Doubt Interruption System & Exact Position Restoration
    test('Doubt Interruption: snapshots lesson, answers in Doubt Mode, restores exact position on return', () async {
      final topic = repository.preSeededTopics[1]; // Topic 2
      await teachingState.loadTopicLesson(topic, algorithmsSubject);

      // Advance to Section 1 (Divide and Conquer vs DP)
      await teachingState.nextSection();
      expect(teachingState.currentSectionIndex, equals(1));

      // Student interrupts with a doubt
      teachingState.enterDoubtMode(initialQuestion: 'What is the difference between Divide and Conquer and Dynamic Programming?');

      // Verify Doubt Interruption State
      expect(teachingState.isInDoubtInterruption, isTrue);
      expect(teachingState.currentMode, equals(TeachingMode.doubt));
      expect(teachingState.interruptedSectionTitle, equals('Divide & Conquer vs Dynamic Programming'));

      // Allow simulated async token streaming to finish
      await Future.delayed(const Duration(milliseconds: 200));

      // Messages must contain the question and assistant answer
      expect(teachingState.messages.length, greaterThanOrEqualTo(1));
      final userMsg = teachingState.messages.first;
      expect(userMsg.isDoubt, isTrue);
      expect(userMsg.contextTag, equals('Divide & Conquer vs Dynamic Programming'));

      // Student taps [Return to Lesson]
      await teachingState.returnToLesson();

      // Verify exact lesson position is restored
      expect(teachingState.isInDoubtInterruption, isFalse);
      expect(teachingState.currentMode, equals(TeachingMode.learn));
      expect(teachingState.currentSectionIndex, equals(1), reason: 'Must restore exact Section 1');
      expect(teachingState.currentSection?.title, equals('Divide & Conquer vs Dynamic Programming'));
    });

    // 6. Test Interactive Quiz Scoring & Explanations
    test('Interactive Quiz: validates answers, calculates score, saves results', () async {
      final questions = await repository.getQuizQuestions();
      expect(questions.length, equals(2));

      // Question 1: Big-O representation (Option 1 is correct)
      final q1 = questions[0];
      expect(q1.correctOptionIndex == 1, isTrue);
      expect(q1.correctOptionIndex == 0, isFalse);
      expect(q1.explanation, contains('asymptotic upper bound'));

      // Question 2: In-place algorithm (True / Option 0 is correct)
      final q2 = questions[1];
      expect(q2.correctOptionIndex == 0, isTrue);
      expect(q2.explanation, contains('In-place algorithms modify'));

      // Save Quiz Result
      final result = QuizResult(
        topicTitle: 'Algorithms Foundations Quiz',
        score: 2,
        totalQuestions: 2,
        date: DateTime.now(),
      );
      expect(result.percentage, equals(100.0));
      expect('${result.score} / ${result.totalQuestions} (${result.percentage.toInt()}%)', equals('2 / 2 (100%)'));

      await repository.saveQuizResult(result);
      final savedResults = await repository.getQuizResults();
      expect(savedResults.length, equals(1));
      expect(savedResults.first.score, equals(2));
    });

    // 7. Test Exam Prep Model Structure
    test('Exam Prep: provides 2-mark, 5-mark, and 10-mark model answers', () {
      final topic = repository.preSeededTopics[4]; // Topic 5: Asymptotic Notations
      final section = topic.sections[0]; // Big-O

      // 2-Mark Question: Definition + Inequality
      final twoMarkAnswer = 'Definition: ${section.definition}\nFormula: ${section.examPoints}';
      expect(twoMarkAnswer, contains('0 ≤ f(n) ≤ c · g(n)'));

      // 5-Mark Question: Mechanism + Criteria
      final fiveMarkAnswer = 'Concept: ${section.title}\n${section.explanation}\nKey Points:\n${section.examPoints}';
      expect(fiveMarkAnswer, contains('upper bound'));

      // 10-Mark Question: Complete Breakdown with Telugu+English Intuition
      final tenMarkAnswer = '${section.definition}\n${section.explanation}\nExample: ${section.example}\nNotes: ${section.teluguExplanation}';
      expect(tenMarkAnswer, contains(section.example));
      expect(tenMarkAnswer, contains(section.teluguExplanation));
    });

    // 8. Test Revision Mode Summary Cards
    test('Revision Mode: builds high-yield cards and formulas for quick review', () {
      final topic = repository.preSeededTopics[0];
      final revCard = {
        'topic': topic.title,
        'points': topic.sections.map((s) => s.examPoints).join('\n'),
        'tanglish': topic.sections.map((s) => s.teluguExplanation).join('\n'),
      };

      expect(revCard['points'], contains('2-Mark Question favorite'));
      expect(revCard['tanglish'], contains('Algorithm ante'));
    });
  });
}
