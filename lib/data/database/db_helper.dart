import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static const String _databaseName = 'ai_teacher.db';
  static const int _databaseVersion = 1;

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        code TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER,
        name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        page_count INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE document_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        content TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        page_number INTEGER,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        summary TEXT,
        order_index INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE lesson_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        definition TEXT NOT NULL,
        importance TEXT,
        explanation TEXT NOT NULL,
        example TEXT,
        telugu_explanation TEXT,
        exam_points TEXT,
        check_question TEXT,
        check_answer TEXT,
        section_order INTEGER NOT NULL,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        topic_id INTEGER NOT NULL UNIQUE,
        current_section_index INTEGER NOT NULL DEFAULT 0,
        total_sections INTEGER NOT NULL DEFAULT 1,
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_studied_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_doubt INTEGER NOT NULL DEFAULT 0,
        context_tag TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER,
        question TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_index INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'mcq',
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_title TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Preload sample Demo Subject: "Algorithms"
    await _seedAlgorithmsDemo(db);
  }

  static Future<void> _seedAlgorithmsDemo(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Insert Subject: Algorithms
    final subjectId = await db.insert('subjects', {
      'title': 'Design & Analysis of Algorithms',
      'description': 'Core Computer Science curriculum: Complexity analysis, sorting, divide & conquer, greedy, and dynamic programming.',
      'code': 'CS301',
      'created_at': now,
    });

    // 2. Insert 6 Standard Topics
    final topicsData = [
      {
        'title': '1. Algorithm Definition & Essentials',
        'summary': 'Fundamental concept of algorithms, inputs, outputs, finiteness, and correctness.',
        'sections': [
          {
            'title': 'What is an Algorithm?',
            'definition': 'An algorithm is a step-by-step, finite sequence of unambiguous instructions designed to solve a computational problem or perform a specific task.',
            'importance': 'Serves as the theoretical blueprint for writing any computer software or system.',
            'explanation': 'Every algorithm accepts zero or more well-defined inputs, processes them through deterministic logical steps, and produces one or more outputs. It must terminate after a finite number of steps.',
            'example': 'Recipe for making tea, or finding the maximum number in a list of integers.',
            'telugu_explanation': 'Algorithm ante oka problem solve cheyadaniki manam step-by-step ga raase clear instructions set.',
            'exam_points': '• Must be finite, unambiguous, and input-output driven.\n• Distinct from a program (independent of programming language syntax).\n• 2-Mark Question favorite: "Define Algorithm and state its criteria."',
            'check_question': 'Can an algorithm run infinitely and still be called a valid algorithm?',
            'check_answer': 'No, finiteness is a strict requirement; an infinite process is called a computational method, not an algorithm.',
          },
          {
            'title': 'Algorithm Properties & Criteria',
            'definition': 'The five canonical criteria formulated by Donald Knuth: Input, Output, Definiteness, Finiteness, and Effectiveness.',
            'importance': 'Used by examiners to verify whether a proposed procedure qualifies as an algorithm.',
            'explanation': '1. Input: 0 or more inputs.\n2. Output: At least 1 output.\n3. Definiteness: Every step is clear and unambiguous.\n4. Finiteness: Terminates in finite steps.\n5. Effectiveness: Operations are simple enough to be done with paper and pencil.',
            'example': 'Division by zero violates Definiteness/Effectiveness because it is undefined.',
            'telugu_explanation': 'Knuth cheppina 5 main criteria: Input, Output, Definiteness (clarity), Finiteness (end avvali), and Effectiveness (practical ga undali).',
            'exam_points': '• Frequently asked as a 5-mark question.\n• Always list all 5 criteria with one line explanation each.',
            'check_question': 'Which property requires every step to have a clear, unique meaning?',
            'check_answer': 'Definiteness.',
          },
        ],
      },
      {
        'title': '2. Properties & Types of Algorithms',
        'summary': 'Major algorithmic paradigms including Brute Force, Divide and Conquer, Greedy, and Dynamic Programming.',
        'sections': [
          {
            'title': 'Algorithm Paradigms Overview',
            'definition': 'An algorithmic paradigm is a generalized approach or framework for designing algorithms to solve problems.',
            'importance': 'Helps categorize and choose the most optimal strategy for any given problem.',
            'explanation': 'Common paradigms:\n• Brute Force: Exhaustive search of all possibilities.\n• Divide & Conquer: Split problem, solve subproblems recursively, combine results.\n• Greedy: Make locally optimal choice at each step.\n• Dynamic Programming: Solve overlapping subproblems and memoize results.',
            'example': 'Divide & Conquer: Merge Sort. Greedy: Kruskal\'s MST. Dynamic Programming: Fibonacci numbers.',
            'telugu_explanation': 'Problem solve chese approaches: Divide & Conquer ante problem ni chinnaga chesi solve cheyadam; Greedy ante appatiki edhi best anipisthe adi pick cheskovadam.',
            'exam_points': '• Compare Divide & Conquer vs Dynamic Programming (Very common 5/10 mark question).\n• Divide & Conquer handles non-overlapping subproblems; DP handles overlapping subproblems.',
            'check_question': 'Which paradigm chooses the best local choice without backtracking?',
            'check_answer': 'Greedy Algorithm paradigm.',
          },
          {
            'title': 'Divide & Conquer vs Dynamic Programming',
            'definition': 'Divide and Conquer solves problems by combining solutions to non-overlapping subproblems; Dynamic Programming memoizes solutions to overlapping subproblems with optimal substructure.',
            'importance': 'Classic 5-mark and 10-mark comparison question in every university algorithms paper.',
            'explanation': 'Key differences:\n1. Subproblems: D&C subproblems are independent (e.g., Merge Sort left/right halves); DP subproblems share common subproblems (e.g., Fibonacci, Bellman-Ford).\n2. Duplication: D&C may recompute identical subproblems multiple times; DP computes each once and stores in a lookup table.\n3. Approaches: DP supports Top-Down (Memoization) and Bottom-Up (Tabulation).',
            'example': 'Computing Fibonacci numbers: Naive recursion takes O(2ⁿ) time with duplicate calls; DP tabulation takes O(n) time and O(n) space.',
            'telugu_explanation': 'Divide and Conquer lo subproblems separate ga untayi (Merge Sort laaga). Dynamic Programming lo subproblems malli malli repeat avthayi, so okasari compute chesi table lo save cheskuntam.',
            'exam_points': '• Draw the recursion tree showing duplicate nodes for Fibonacci.\n• Create a two-column comparison table: Concept, Subproblem type, Efficiency, and Canonical Examples.',
            'check_question': 'What are the two core conditions required to apply Dynamic Programming?',
            'check_answer': 'Overlapping Subproblems and Optimal Substructure.',
          },
        ],
      },
      {
        'title': '3. Algorithm Analysis Framework',
        'summary': 'Theoretical framework for evaluating algorithm efficiency independently of machine hardware.',
        'sections': [
          {
            'title': 'Why Analyze Algorithms?',
            'definition': 'Algorithm analysis is the study of resource consumption (CPU time and memory space) relative to input size n.',
            'importance': 'Enables developers to predict performance without running on different physical hardware architectures.',
            'explanation': 'Execution time measured in wall-clock seconds varies across processors, compiler optimizations, and background processes. Theoretical analysis counts the number of elementary operations executed as a function of input size n.',
            'example': 'Comparing Linear Search (n operations) with Binary Search (log n operations) on 1,000,000 items.',
            'telugu_explanation': 'Algorithm analysis ante computer speed tho sambandham lekunda input size n perigithe time and memory entha peruguthundo calculate cheyadam.',
            'exam_points': '• Independent of machine, language, or compiler.\n• Focuses on rate of growth (asymptotic growth) as n approaches infinity.',
            'check_question': 'Why do we avoid measuring actual execution time in seconds for algorithm comparison?',
            'check_answer': 'Because wall-clock time depends on CPU clock speed, RAM speed, OS scheduling, and compiler optimizations.',
          },
          {
            'title': 'Best-Case, Worst-Case, and Average-Case Analysis',
            'definition': 'Analysis based on input configurations: Worst-case provides the upper bound on any input; Best-case provides the lower bound; Average-case calculates the expected time over all valid inputs.',
            'importance': 'Helps software engineers make informed trade-offs between guaranteed safety and real-world expected runtime.',
            'explanation': '1. Worst-Case Time (W(n)): Maximum number of steps across all inputs of size n. Always provides a deterministic guarantee.\n2. Best-Case Time (B(n)): Minimum steps executed on the most favorable input. Often trivial (e.g., target element at index 0 in linear search).\n3. Average-Case Time (A(n)): Expected steps assuming a probability distribution over all inputs. Requires calculating expected value across all permutations.',
            'example': 'Linear Search: Best-case is O(1) (found at index 0); Worst-case is O(n) (not found or at the end); Average-case is O(n/2) = O(n). Quick Sort: Best/Average is O(n log n); Worst-case is O(n²).',
            'telugu_explanation': 'Worst-case ante hardest input ki entha time paduthundo (maximum time). Best-case ante easiest input ki (minimum time). Average-case ante standard average performance.',
            'exam_points': '• Professors usually demand: "Why is worst-case analysis preferred over average-case?"\n• Answer: Worst-case gives an absolute guarantee and does not rely on unknown probability assumptions.',
            'check_question': 'Why is average-case analysis typically more difficult to compute than worst-case analysis?',
            'check_answer': 'Because it requires determining or assuming the exact probability distribution of all possible input configurations.',
          },
        ],
      },
      {
        'title': '4. Time Complexity & Growth Rates',
        'summary': 'Understanding how run-time scales with input size n: constant, logarithmic, linear, quadratic, exponential.',
        'sections': [
          {
            'title': 'Order of Growth',
            'definition': 'The order of growth describes how quickly the execution time increases when the input size n increases.',
            'importance': 'Distinguishes between practical algorithms and computationally intractable algorithms.',
            'explanation': 'Hierarchy of common complexities from fastest to slowest:\n1. O(1) - Constant Time\n2. O(log n) - Logarithmic Time\n3. O(n) - Linear Time\n4. O(n log n) - Linearithmic Time\n5. O(n²) - Quadratic Time\n6. O(2ⁿ) - Exponential Time',
            'example': 'Accessing array element by index is O(1); Bubble sort is O(n²); Tower of Hanoi is O(2ⁿ).',
            'telugu_explanation': 'Input size n peddadi aithe, execution time entha speed tho perugutundo order of growth antam. O(1) fastest, O(2ⁿ) chala slow.',
            'exam_points': '• Draw the graph of n vs Operations for 5-mark answer.\n• Emphasize that for large n, constants become negligible.',
            'check_question': 'Which is faster for n = 1,000,000: O(n log n) or O(n²)?',
            'check_answer': 'O(n log n) is dramatically faster; ~20 million ops vs 1 trillion ops.',
          },
          {
            'title': 'Analyzing Loops & Recurrence Relations',
            'definition': 'Techniques for determining complexity of iterative code (counting loop iterations) and recursive code (solving recurrence relations via Master Theorem).',
            'importance': 'Standard practical examination questions where students must analyze code snippets and compute Big-O.',
            'explanation': 'Rules of Thumb:\n• Single loop from 1 to n with step 1: O(n)\n• Loop with step i = i * 2: O(log n)\n• Nested loops where outer is n and inner is n: O(n²)\n• Master Theorem for T(n) = aT(n/b) + f(n):\n  - If f(n) = O(n^{log_b(a) - ε}), T(n) = Θ(n^{log_b a})\n  - If f(n) = Θ(n^{log_b a}), T(n) = Θ(n^{log_b a} · log n)',
            'example': 'Merge Sort recurrence: T(n) = 2T(n/2) + O(n). Here a=2, b=2, log_b(a)=1. By Master Theorem Case 2, T(n) = Θ(n log n).',
            'telugu_explanation': 'Loops unte iterations count chestham (nested loops aithe n*n = n²). Recursion equations vachinapudu Master Theorem formula use chesi direct ga answer calculate cheyachu.',
            'exam_points': '• State the Master Theorem formula and its 3 cases clearly.\n• Show step-by-step substitution when analyzing nested loop bounds.',
            'check_question': 'What is the time complexity of a loop where index i doubles in each step (for i=1; i<n; i*=2)?',
            'check_answer': 'O(log n) because the number of iterations k satisfies 2ᵏ ≈ n, giving k ≈ log₂ n.',
          },
        ],
      },
      {
        'title': '5. Asymptotic Notations: Big O, Omega, Theta',
        'summary': 'Mathematical definitions of asymptotic bounds: Upper bound (O), Lower bound (Ω), and Tight bound (Θ).',
        'sections': [
          {
            'title': 'Big-O Notation (Upper Bound)',
            'definition': 'f(n) = O(g(n)) if there exist positive constants c and n₀ such that 0 ≤ f(n) ≤ c · g(n) for all n ≥ n₀.',
            'importance': 'Guarantees the worst-case maximum time an algorithm will ever take.',
            'explanation': 'Big-O provides an asymptotic upper bound. It means the algorithm will never take more time than c · g(n) for sufficiently large n. It represents the ceiling of the running time.',
            'example': 'Insertion Sort worst-case is O(n²); Binary Search is O(log n).',
            'telugu_explanation': 'Big O ante upper bound - worst case lo algorithm maximum entha time theesukuntundo guarantee istundi. Dini kante ekkuva time pattadu.',
            'exam_points': '• Write the exact mathematical equation: 0 ≤ f(n) ≤ c·g(n) for n ≥ n₀.\n• State that Big O gives worst-case safety guarantee.\n• Most common 2-mark & 5-mark question in every semester exam.',
            'check_question': 'What does the constant n₀ represent in the definition of Big O?',
            'check_answer': 'The threshold input size beyond which the inequality f(n) ≤ c·g(n) strictly holds.',
          },
          {
            'title': 'Big-Omega (Ω) and Big-Theta (Θ) Notations',
            'definition': 'Big-Omega (Ω) represents the asymptotic lower bound: 0 ≤ c · g(n) ≤ f(n) for n ≥ n₀. Big-Theta (Θ) represents the tight bound: c₁ · g(n) ≤ f(n) ≤ c₂ · g(n) for n ≥ n₀.',
            'importance': 'Big-Omega gives best-case guarantee; Big-Theta gives exact growth rate when upper and lower bounds coincide.',
            'explanation': '• Big-Omega (Ω): Algorithm takes at least this much time.\n• Big-Theta (Θ): Algorithm is sandwiched between c₁ and c₂. We only say f(n) = Θ(g(n)) if f(n) = O(g(n)) and f(n) = Ω(g(n)).',
            'example': 'Linear search best case (found at index 0) is Ω(1). Merge Sort is Θ(n log n) in all cases.',
            'telugu_explanation': 'Omega (Ω) ante minimum time (lower bound). Theta (Θ) ante exact time (both upper and lower bound kalisi unte).',
            'exam_points': '• Draw the three curves: upper bound c·g(n), f(n), and lower bound c·g(n).\n• State the condition for Theta: f(n)=Θ(g(n)) iff f(n)=O(g(n)) and f(n)=Ω(g(n)).',
            'check_question': 'If an algorithm is both O(n) and Ω(n), what is its Theta bound?',
            'check_answer': 'Θ(n).',
          },
          {
            'title': 'Strict Bounds: Little-o and Little-omega',
            'definition': 'Little-o (o) denotes a non-tight upper bound where f(n) grows strictly slower than g(n). Little-omega (ω) denotes a strict lower bound where f(n) grows strictly faster than g(n).',
            'importance': 'Tested in competitive exams and university theory questions on asymptotic limits.',
            'explanation': 'Limit definitions:\n• Little-o: lim_{n→∞} f(n)/g(n) = 0. Example: 2n = o(n²), but 2n² ≠ o(n²).\n• Little-omega: lim_{n→∞} f(n)/g(n) = ∞. Example: n² = ω(n).\nAnalogy with arithmetic:\n• Big-O is like ≤\n• Big-Omega is like ≥\n• Big-Theta is like =\n• Little-o is like <\n• Little-omega is like >',
            'example': '3n + 5 = O(n) and 3n + 5 = O(n²). But 3n + 5 = o(n²) is true, while 3n + 5 = o(n) is FALSE.',
            'telugu_explanation': 'Big O ante ≤ (less than or equal to). Little o ante strictly < (strictly less than). Limit n→∞ f(n)/g(n) = 0 aithe Little o antam.',
            'exam_points': '• Write the limit definition: lim_{n→∞} [f(n)/g(n)] = 0 for Little-o.\n• Mention the mathematical analogy with real number inequalities (≤, ≥, =, <, >).',
            'check_question': 'Is 5n² = o(n²)?',
            'check_answer': 'No, because the limit as n→∞ of (5n²/n²) is 5, not 0. 5n² is O(n²) and Θ(n²), but not o(n²).',
          },
        ],
      },
      {
        'title': '6. Space Complexity & Auxiliary Memory',
        'summary': 'Memory requirements of algorithms: fixed vs variable parts, recursion stack space, and in-place algorithms.',
        'sections': [
          {
            'title': 'Space Complexity & Auxiliary Space',
            'definition': 'Space Complexity is the total amount of memory space required by the algorithm with respect to input size n. Auxiliary space is the extra space used excluding input space.',
            'importance': 'Critical in embedded devices, mobile apps, and memory-constrained environments.',
            'explanation': 'Space Complexity = Fixed Part (code space, simple variables) + Variable Part (dynamically allocated memory, recursive call stack). An in-place algorithm has auxiliary space O(1).',
            'example': 'Merge sort requires O(n) auxiliary space for temp arrays. Quick sort requires O(log n) auxiliary stack space.',
            'telugu_explanation': 'Space complexity ante algorithm run avvadaniki entha memory kavalo adi. Extra ga use chese memory ni auxiliary space antaru.',
            'exam_points': '• Differentiate Space Complexity vs Auxiliary Space (Important 2-mark question).\n• In-place sorting algorithms use O(1) auxiliary space.',
            'check_question': 'Does an algorithm that modifies an array in-place without extra arrays have O(1) auxiliary space?',
            'check_answer': 'Yes, in-place algorithms utilize O(1) auxiliary space.',
          },
          {
            'title': 'Recursion Stack Space & In-Place Algorithms',
            'definition': 'Recursion stack space refers to the memory allocated on the call stack for function activation records. In-place algorithms require O(1) auxiliary space beyond the input data.',
            'importance': 'Crucial for understanding memory limits, stack overflow errors, and optimizing resource-constrained code.',
            'explanation': 'Every recursive call pushes an activation record (return address, parameter values, local variables) onto the system stack.\n• Depth of recursion tree determines stack space.\n• Balanced recursion tree of depth d requires O(d) stack space.\n• Tail recursion can be optimized by compilers into loops to eliminate stack overhead.',
            'example': 'Tree traversal on balanced binary tree of depth log n requires O(log n) stack frames; on skewed tree it requires O(n) stack frames. In-place sorting: Heap Sort uses O(1) auxiliary space; Merge Sort uses O(n).',
            'telugu_explanation': 'Function tana ni tanu call cheskunappudu system call stack lo frame create avthundi. Tree depth batti memory spend avtundi. Extra memory lekunda same array lo sort chesthe In-place algorithm antaru.',
            'exam_points': '• Explain Activation Record components (parameters, return address, local variables).\n• Contrast Merge Sort (O(n) auxiliary) with Quick Sort (O(log n) stack auxiliary) and Heap Sort (O(1) in-place).',
            'check_question': 'What causes a StackOverflowError in recursive algorithms?',
            'check_answer': 'Excessive recursion depth without reaching a base case, exhausting the finite memory allocated to the thread call stack.',
          },
        ],
      },
    ];

    for (int tIdx = 0; tIdx < topicsData.length; tIdx++) {
      final t = topicsData[tIdx];
      final topicId = await db.insert('topics', {
        'subject_id': subjectId,
        'title': t['title'],
        'summary': t['summary'],
        'order_index': tIdx,
        'is_completed': 0,
      });

      final sections = t['sections'] as List<Map<String, dynamic>>;
      for (int sIdx = 0; sIdx < sections.length; sIdx++) {
        final s = sections[sIdx];
        await db.insert('lesson_sections', {
          'topic_id': topicId,
          'title': s['title'],
          'definition': s['definition'],
          'importance': s['importance'],
          'explanation': s['explanation'],
          'example': s['example'],
          'telugu_explanation': s['telugu_explanation'],
          'exam_points': s['exam_points'],
          'check_question': s['check_question'],
          'check_answer': s['check_answer'],
          'section_order': sIdx,
        });
      }

      // Initialize lesson progress for topic
      await db.insert('lesson_progress', {
        'subject_id': subjectId,
        'topic_id': topicId,
        'current_section_index': 0,
        'total_sections': sections.length,
        'is_completed': 0,
        'last_studied_at': now,
      });
    }

    // 3. Preload Sample Exam Questions for the Subject
    final sampleQuestions = [
      {
        'topic_id': null,
        'question': 'What does Big-O notation mathematically represent?',
        'options': 'Exact execution time in seconds|||Asymptotic upper-bound growth rate|||Physical memory address allocation|||Target programming language complexity',
        'correct_index': 1,
        'explanation': 'Big-O gives an asymptotic upper bound, guaranteeing the maximum running time for large input sizes n.',
        'type': 'mcq',
      },
      {
        'topic_id': null,
        'question': 'An algorithm that operates using only O(1) extra memory is called an in-place algorithm.',
        'options': 'True|||False',
        'correct_index': 0,
        'explanation': 'In-place algorithms modify input data structures without using extra auxiliary memory proportional to n.',
        'type': 'true_false',
      },
      {
        'topic_id': null,
        'question': 'Which of the following is Donald Knuth\'s algorithm criterion requiring every instruction to be clear and unambiguous?',
        'options': 'Finiteness|||Effectiveness|||Definiteness|||Generality',
        'correct_index': 2,
        'explanation': 'Definiteness requires every step of the algorithm to be precisely stated without ambiguity.',
        'type': 'mcq',
      },
      {
        'topic_id': null,
        'question': 'If an algorithm has both O(n log n) and Ω(n log n) bounds, its tight bound is Θ(n log n).',
        'options': 'True|||False',
        'correct_index': 0,
        'explanation': 'By definition, f(n) = Θ(g(n)) if and only if f(n) = O(g(n)) and f(n) = Ω(g(n)).',
        'type': 'true_false',
      },
      {
        'topic_id': null,
        'question': 'Which growth rate grows the fastest as n becomes very large?',
        'options': 'O(n²) Quadratic|||O(n log n) Linearithmic|||O(2ⁿ) Exponential|||O(n) Linear',
        'correct_index': 2,
        'explanation': 'Exponential growth O(2ⁿ) quickly becomes computationally intractable for even modest n.',
        'type': 'mcq',
      },
    ];

    for (final q in sampleQuestions) {
      await db.insert('quiz_questions', q);
    }
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
