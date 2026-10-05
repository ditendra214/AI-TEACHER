import 'dart:async';
import 'ai_provider.dart';

/// Offline heuristic tutor engine used when no GGUF model or API is configured
class FallbackTeacherProvider implements AiProvider {
  @override
  String get name => 'Offline Rule-Based Exam Tutor';

  @override
  bool get isReady => true;

  @override
  Future<String> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    return _generateRuleBasedResponse(prompt);
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async* {
    final fullText = _generateRuleBasedResponse(prompt);
    final words = fullText.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield '${words[i]} ';
      // Simulate realistic streaming cadence
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  String _generateRuleBasedResponse(String prompt) {
    final lower = prompt.toLowerCase();

    // Check if relevant document excerpts were provided in the prompt
    final extractRegex = RegExp(r'--- Extract \d+ ---\n([\s\S]*?)(?=---|Use the above|$)', multiLine: true);
    final matches = extractRegex.allMatches(prompt);

    if (matches.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('**According to your study material:**\n');
      for (final m in matches.take(2)) {
        final snippet = m.group(1)?.trim();
        if (snippet != null && snippet.isNotEmpty) {
          // Truncate to first 300 characters
          final displaySnippet = snippet.length > 350 ? '${snippet.substring(0, 350)}...' : snippet;
          buffer.writeln('> $displaySnippet\n');
        }
      }
      buffer.writeln('**Key Exam Takeaway:**');
      buffer.writeln('• Review this section carefully before the exam.');
      buffer.writeln('• Focus on core definitions and diagrams/steps.');
      buffer.writeln('\n*(Note: For interactive generative AI answers, import a GGUF model in AI Model Setup).*');
      return buffer.toString();
    }

    // Common Computer Science / Engineering exam concepts
    if (lower.contains('big o') || lower.contains('time complexity') || lower.contains('asymptotic')) {
      return '''**Time Complexity & Big O Notation**

**1. Definition:**
Big O notation mathematically describes the upper bound (worst-case scenario) of an algorithm's execution time as the input size \$n\$ grows toward infinity.

**2. Formula:**
\$f(n) = O(g(n))\$ if there exist positive constants \$c > 0\$ and \$n_0 \\ge 1\$ such that:
\\[0 \\le f(n) \\le c \\cdot g(n) \\quad \\text{for all } n \\ge n_0\\]

**3. Common Complexity Hierarchy (Fastest to Slowest):**
• **O(1)** — Constant Time (e.g., array index lookup)
• **O(log n)** — Logarithmic Time (e.g., Binary Search)
• **O(n)** — Linear Time (e.g., Linear Search)
• **O(n log n)** — Linearithmic Time (e.g., Merge Sort, Quick Sort)
• **O(n²)** — Quadratic Time (e.g., Bubble Sort, Selection Sort)
• **O(2ⁿ)** — Exponential Time (e.g., Recursive Fibonacci)

**4. Telugu + English Summary:**
Big O ante algorithm worst case lo maximum entha time theesukuntundo cheppe upper bound. Idi input size \$n\$ perigithe performance ela untundo predict chestundi.

**5. Exam Tip (2 Marks):**
Always write the inequality \$0 \\le f(n) \\le c \\cdot g(n)\$ and state that \$c\$ and \$n_0\$ are positive constants.''';
    }

    if (lower.contains('divide and conquer') || lower.contains('dynamic programming') || lower.contains('greedy')) {
      return '''**Algorithmic Paradigms: Divide & Conquer vs Dynamic Programming**

**1. Core Distinctions:**
• **Divide & Conquer:** Splits a problem into independent, non-overlapping subproblems, solves each recursively, and combines results (e.g., Merge Sort, Binary Search).
• **Dynamic Programming:** Solves problems with overlapping subproblems and optimal substructure by memoizing subproblem results into a table to eliminate duplicate computation.
• **Greedy:** Makes the locally optimal choice at each stage with the hope of finding a global optimum without backtracking (e.g., Kruskal's, Dijkstra's).

**2. Complexity Comparison:**
• Computing Fibonacci via naive recursion: \$O(2^n)\$ time.
• Computing Fibonacci via DP tabulation: \$O(n)\$ time and \$O(n)\$ space.

**3. Telugu + English:**
Divide & Conquer lo subproblems separate ga untayi. Dynamic Programming lo subproblems malli malli repeat avthayi kabatti oka table lo save cheskuni reuse chestham.

**4. Exam Tip (5/10 Marks):**
Draw the subproblem dependency graph and explain Top-Down Memoization vs Bottom-Up Tabulation.''';
    }

    if (lower.contains('omega') || lower.contains('theta') || lower.contains('little-o') || lower.contains('little o')) {
      return '''**Asymptotic Bounds: Big-Omega (Ω) and Big-Theta (Θ)**

**1. Definitions:**
• **Big-Omega (Ω):** Asymptotic lower bound. \$0 \\le c \\cdot g(n) \\le f(n)\$ for all \$n \\ge n_0\$. Gives the best-case running time.
• **Big-Theta (Θ):** Asymptotic tight bound. \$c_1 \\cdot g(n) \\le f(n) \\le c_2 \\cdot g(n)\$ for all \$n \\ge n_0\$.
• **Little-o (o):** Strict non-tight upper bound where \$\\lim_{n \\to \\infty} \\frac{f(n)}{g(n)} = 0\$.

**2. Equivalence Theorem:**
An algorithm satisfies \$f(n) = \\Theta(g(n))\$ if and only if \$f(n) = O(g(n))\$ and \$f(n) = \\Omega(g(n))\$.

**3. Telugu + English:**
Omega ante minimum time (lower bound). Theta ante exact tight bound (upper and lower bound match aithe).

**4. Exam Tip (5 Marks):**
Always draw the 3 curves: upper bound \$c_2 \\cdot g(n)\$, function \$f(n)\$, and lower bound \$c_1 \\cdot g(n)\$.''';
    }

    if (lower.contains('space complexity') || lower.contains('auxiliary') || lower.contains('in-place')) {
      return '''**Space Complexity & Auxiliary Space**

**1. Definitions:**
• **Space Complexity:** Total memory used by an algorithm during execution as a function of input size \$n\$ (includes input memory + auxiliary memory).
• **Auxiliary Space:** Extra temporary space or data structures used by the algorithm, excluding the space taken by input.
• **In-Place Algorithm:** An algorithm that operates with \$O(1)\$ auxiliary memory.

**2. Key Examples:**
• **Merge Sort:** \$O(n)\$ auxiliary space for auxiliary merge arrays.
• **Quick Sort:** \$O(\\log n)\$ auxiliary stack space for recursion.
• **Heap Sort:** \$O(1)\$ auxiliary space (strictly in-place).

**3. Telugu + English:**
Space complexity ante input tho saha motham entha RAM vadutundo. Auxiliary space ante extra ga create chesina arrays or variables memory.

**4. Exam Tip (2 Marks):**
Clearly state: "Space Complexity = Input Space + Auxiliary Space".''';
    }

    if (lower.contains('worst case') || lower.contains('best case') || lower.contains('average case')) {
      return '''**Algorithm Analysis: Best, Worst, and Average Cases**

**1. Definitions:**
• **Worst-Case Time:** Maximum steps over all inputs of size \$n\$. Guarantees upper safety limit.
• **Best-Case Time:** Minimum steps over any input of size \$n\$. Often an idealized trivial case.
• **Average-Case Time:** Expected steps assuming a uniform probability distribution over all valid inputs.

**2. Linear Search Case Study:**
• Best Case: \$O(1)\$ (target found at index 0).
• Worst Case: \$O(n)\$ (target at index \$n-1\$ or absent).
• Average Case: \$\\frac{n+1}{2} = O(n)\$.

**3. Telugu + English:**
Worst case ante maximum entha late avvacho guarantee ivvadam. Real-world systems lo worst case guarantee unte system crash avvakunda safe ga untundi.

**4. Exam Tip (5 Marks):**
Explain why engineers prioritize Worst-Case analysis: it requires no assumptions about input distribution and prevents system timeouts.''';
    }

    if (lower.contains('recursion') || lower.contains('recursive') || lower.contains('stack')) {
      return '''**Recursion in Computer Science**

**1. Definition:**
Recursion is a programming technique where a function solves a problem by calling itself with smaller sub-problems until reaching a base condition.

**2. Key Components:**
• **Base Case:** The termination condition that prevents infinite looping and stack overflow.
• **Recursive Step:** The logic that breaks the problem into a smaller instance and calls itself.

**3. Telugu + English:**
Recursion ante oka function tana own ni malli call cheskovadam. Base case lekapothe stack overflow error vastundi.

**4. Exam Question:**
"Differentiate Iteration vs Recursion."
• Iteration uses loops (for/while); Recursion uses function call stack.
• Iteration requires \$O(1)\$ auxiliary memory; Recursion takes \$O(n)\$ stack frame memory.''';
    }

    if (lower.contains('algorithm') || lower.contains('properties')) {
      return '''**Algorithm Fundamentals & Properties**

**1. Definition:**
An algorithm is a finite, ordered sequence of unambiguous instructions designed to solve a computational problem.

**2. Donald Knuth's 5 Criteria (Important 5-Mark Question):**
1. **Input:** Must accept zero or more external values.
2. **Output:** Must produce at least one output result.
3. **Definiteness:** Every step must be clear and unambiguous.
4. **Finiteness:** Must terminate after a finite number of steps.
5. **Effectiveness:** Every operation must be feasible and basic enough to compute.

**3. Telugu + English:**
Algorithm ante oka problem ni solve cheyadaniki step-by-step instructions. Finiteness undali (terminate avvali) and Definiteness undali (clear ga undali).''';
    }

    // API & Web Services
    if (lower.contains('api') || lower.contains('rest') || lower.contains('endpoint') || lower.contains('http')) {
      return '''**Application Programming Interface (API) & REST Architecture**

**1. Definition & Core Concept:**
An API (Application Programming Interface) is a messenger or communication contract that allows two different software systems to communicate and exchange data securely over protocols like HTTP/HTTPS.

**2. Real-World Analogy (Restaurant Waiter):**
Think of an API as a waiter in a restaurant:
• Client (Mobile App/Browser) = Customer ordering food.
• API = Waiter taking your order and delivering the food.
• Server / Database = Kitchen preparing the order.

**3. REST Architectural Principles (Representational State Transfer):**
• **Statelessness:** Every request contains all necessary credentials and data; server retains no client session context.
• **Client-Server Separation:** UI concerns are separate from data storage concerns.
• **Uniform Interface:** Standard HTTP methods:
  - `GET`: Read / retrieve resource data.
  - `POST`: Create a new resource.
  - `PUT`: Replace or update an entire existing resource.
  - `PATCH`: Partially update a resource.
  - `DELETE`: Remove a resource.
• **Standard HTTP Status Codes:**
  - `200 OK`, `201 Created`
  - `400 Bad Request`, `401 Unauthorized`, `404 Not Found`
  - `500 Internal Server Error`

**4. Telugu + English (Classroom Explanation):**
API ante simple ga browser page ki server ki madhyalo service path ni API ani antaru. Restaurant lo waiter customer daggara nundi order theeskuni kitchen ki velli food techinattu, API mana phone screen nundi request theeskuni cloud server daggara nundi data thestundi. Technical ga REST API lo GET data chudadaniki, POST kotha data create cheyadaniki vadatharu.

**5. Exam Tip (5/10 Marks):**
Draw the 3-tier diagram: Client (Mobile/Web) <---> HTTP Request/Response (JSON payload) <---> Server (Controller/Service) <---> Database.''';
    }

    // Python Programming
    if (lower.contains('python') || lower.contains('list comprehension') || lower.contains('gil') || lower.contains('duck typing')) {
      return '''**Python Programming: Core Concepts & Architecture**

**1. Language Characteristics:**
• **Interpreted & High-Level:** Executes bytecode line-by-line via the Python Virtual Machine (PVM).
• **Dynamically Typed:** Variable types are resolved at runtime without explicit declarations.
• **Automatic Memory Management:** Reference counting combined with a cyclic garbage collector.

**2. Key Built-in Data Structures:**
• **List:** Ordered, mutable sequence `[1, 2, 3]`.
• **Tuple:** Ordered, immutable sequence `(1, 2, 3)`.
• **Set:** Unordered collection of unique items `{1, 2, 3}`.
• **Dictionary:** Key-value pairs with O(1) average lookup `{"key": "value"}`.

**3. Advanced Python Features for Exams:**
• **List Comprehension:** Clean syntax for transforming iterables: `[x**2 for x in range(10) if x % 2 == 0]`.
• **Global Interpreter Lock (GIL):** A mutex in CPython that prevents multiple native threads from executing Python bytecodes simultaneously.
• **Duck Typing:** "If it walks like a duck and quacks like a duck, it's a duck" — emphasizes object capabilities over explicit class inheritance.

**4. Telugu + English (Classroom Explanation):**
Python chala readable and beginner-friendly language. Ikkada semicolons or curly braces undavu, indentation (spacing) chala important. Dynamic typing kabatti `x = 10` ani direct ga rayochu, type declare cheyalsina avasaram ledu. List mutable (change cheyochu), tuple immutable (change cheyalemu).

**5. Exam Tip (5 Marks):**
Write code snippets demonstrating: List vs Tuple difference, List comprehension, and how exception handling works using `try`, `except`, `finally` blocks.''';
    }

    // DBMS & SQL
    if (lower.contains('dbms') || lower.contains('database') || lower.contains('sql') || lower.contains('acid') || lower.contains('normalization')) {
      return '''**Database Management Systems (DBMS) & Relational Design**

**1. ACID Properties (Transaction Management):**
• **Atomicity:** All-or-nothing execution; if any step fails, the transaction rolls back.
• **Consistency:** Database transitions from one valid state to another, satisfying all integrity constraints.
• **Isolation:** Concurrently executing transactions do not interfere with each other.
• **Durability:** Once committed, data modifications persist even through power outages or system crashes.

**2. Database Normalization (Eliminating Redundancy):**
• **1NF (First Normal Form):** Atomic column values, no repeating groups.
• **2NF:** In 1NF and no partial functional dependency (all non-key attributes fully depend on candidate key).
• **3NF:** In 2NF and no transitive dependency (\$X \\to Y\$ and \$Y \\to Z\$).
• **BCNF (Boyce-Codd NF):** For every functional dependency \$X \\to Y\$, \$X\$ must be a super key.

**3. Primary Key vs Foreign Key:**
• **Primary Key:** Unique, non-null identifier for each tuple in a table.
• **Foreign Key:** Reference to a primary key in another table, enforcing referential integrity.

**4. Telugu + English (Classroom Explanation):**
DBMS lo data tables format lo safe ga store avthundi. ACID properties exam lo super important: Atomicity ante pani motham avvali leda asalu jaragakudadhu (like bank money transfer). Normalization ante data duplicate avvakunda tables ni neat ga divide cheyadam.

**5. Exam Tip (10 Marks):**
Draw the bank transfer transaction diagram to explain ACID properties, and explain 1NF, 2NF, 3NF with a Student-Course table example.''';
    }

    // Operating Systems
    if (lower.contains('operating system') || lower.contains('os') || lower.contains('deadlock') || lower.contains('paging') || lower.contains('process')) {
      return '''**Operating Systems: Processes, Threads & Concurrency**

**1. Process vs Thread:**
• **Process:** Program in execution with its own dedicated memory address space (text, data, heap, stack). High context switch overhead.
• **Thread:** Lightweight execution unit within a process. Threads of the same process share code, data, and OS resources, but have independent stacks and registers.

**2. Deadlock & The 4 Coffman Conditions:**
A deadlock occurs when a set of processes are blocked because each process holds a resource and waits for another resource held by another process:
1. **Mutual Exclusion:** Resources cannot be shared simultaneously.
2. **Hold and Wait:** Process holds at least one resource and requests others.
3. **No Preemption:** Resources cannot be forcibly seized; only released voluntarily.
4. **Circular Wait:** Closed chain of processes waiting on each other (\$P_0 \\to P_1 \\to ... \\to P_0\$).

**3. Virtual Memory & Paging:**
• Physical memory is divided into fixed-size **Frames**.
• Logical memory is divided into same-sized **Pages**.
• **Page Table** maps logical page numbers to physical frame numbers. A **Page Fault** occurs when a requested page is not in physical RAM.

**4. Telugu + English (Classroom Explanation):**
Operating System computer hardware ki software ki bridge la work avthundi. Process ante running program, Thread ante process lopala unde lightweight task. Deadlock ante rendu process lu okati inkodanikosam wait chesthu computer freeze ayye state. Paging valla RAM overflow avvakunda virtual memory use chestham.

**5. Exam Tip (5/10 Marks):**
State the 4 Coffman conditions for Deadlock and explain Banker's Algorithm for deadlock avoidance with resource allocation tables.''';
    }

    // Computer Networks
    if (lower.contains('osi model') || lower.contains('osi 7') || lower.contains('tcp') || lower.contains('udp') || lower.contains('transport layer') || lower.contains('3-way handshake') || lower.contains('ip addressing')) {
      return '''**Computer Networks: OSI Model & Transport Layer Protocols**

**1. The 7-Layer OSI Reference Model:**
7. **Application:** End-user protocols (HTTP, DNS, SMTP, FTP).
6. **Presentation:** Data formatting, encryption/decryption (SSL/TLS), compression.
5. **Session:** Dialog control and session synchronization.
4. **Transport:** End-to-end delivery, segmentation, flow/error control (TCP, UDP).
3. **Network:** Logical addressing and packet routing across networks (IP, ICMP, Routers).
2. **Data Link:** Framing, physical MAC addressing, error detection (Ethernet, Switches).
1. **Physical:** Transmission of raw bit streams over physical media (Cables, Hubs).

**2. TCP vs UDP Comparison:**
• **TCP (Transmission Control Protocol):** Connection-oriented, guarantees ordered and reliable delivery via 3-way handshake (`SYN` \$\\to\$ `SYN-ACK` \$\\to\$ `ACK`), flow control, and retransmission.
• **UDP (User Datagram Protocol):** Connectionless, unreliable, low-overhead, no ordering guarantees. Ideal for real-time video streaming, DNS lookups, and online gaming.

**3. Telugu + English (Classroom Explanation):**
Networks lo OSI 7 layers chala standard question: Physical nundi Application varaku order gurthunchukovali. TCP ante reliable phone call lantiది, pakka data reach avthundi. UDP ante speed courier or live streaming lantiది, konchem packets miss aina problem undadu kani speed fast ga untundi.

**4. Exam Tip (10 Marks):**
Always draw the 7-layer OSI vertical stack diagram and write the 3-Way Handshake step sequence for TCP connection establishment.''';
    }

    // Data Structures
    if (lower.contains('tree') || lower.contains('graph') || lower.contains('linked list') || lower.contains('stack') || lower.contains('queue') || lower.contains('dsa')) {
      return '''**Data Structures: Fundamentals & Operations**

**1. Linear vs Non-Linear Structures:**
• **Linear:** Elements arranged sequentially: Arrays, Linked Lists, Stacks (LIFO), Queues (FIFO).
• **Non-Linear:** Elements arranged hierarchically or interconnected: Trees, Binary Search Trees (BST), Heaps, Graphs.

**2. Binary Search Tree (BST) Properties:**
• For every node \$N\$:
  - All keys in left subtree are strictly less than \$N.key\$.
  - All keys in right subtree are strictly greater than \$N.key\$.
• **Search/Insert Time:** \$O(\\log n)\$ average, \$O(n)\$ worst case (skewed tree).

**3. Graph Traversal Algorithms:**
• **Breadth-First Search (BFS):** Level-order traversal using a **Queue**. Time: \$O(V + E)\$. Finds shortest path in unweighted graphs.
• **Depth-First Search (DFS):** Explores as deep as possible before backtracking using a **Stack** or recursion. Time: \$O(V + E)\$. Used in topological sorting and cycle detection.

**4. Telugu + English (Classroom Explanation):**
Data structures ante data ni efficient ga computer memory lo organize cheyadam. Stack ante Last In First Out (plates stack laaga). Queue ante First In First Out (ticket line laaga). Tree and Graph non-linear data structures, complex data relationships ni store cheyadaniki vadatharu.

**5. Exam Tip (5/10 Marks):**
Write the algorithm for BST Insertion and trace BFS traversal step-by-step with a sample graph using adjacency list.''';
    }

    // Extract student question and active section for context-grounded response
    final questionMatch = RegExp(r'Student Question:\s*([^\n]+)').firstMatch(prompt);
    final extractedQuestion = questionMatch != null ? questionMatch.group(1)?.trim() : 'Your query';

    final sectionMatch = RegExp(r'\[ACTIVE SECTION\]:\s*([^\n]+)').firstMatch(prompt);
    final activeSection = sectionMatch != null ? sectionMatch.group(1)?.trim() : 'Active Lesson';

    // Default rich, non-blank structured response
    return '''**$activeSection — Detailed Concept Explanation**

**1. Core Concept Overview:**
Regarding "$extractedQuestion": In university engineering examinations, questions on this topic test your understanding of foundational definitions, standard mechanics, and trade-offs.

**2. Key Working Principles:**
• **Deterministic Logic:** Each step progresses systematically toward the solution.
• **Time & Memory Bounds:** Always specify the complexity order \$O(n)\$ and auxiliary overhead.
• **Mathematical Representation:** Clearly state governing equations and assumptions.

**3. Telugu + English Summary:**
Ee concept lo important point: clear ga definitions, formulas, and step-by-step points rayali. Technical terms ni English lo unchi exam sheet lo neat headings pettali.

**4. Exam Scoring Advice:**
• Draw neat diagrams or flowcharts to earn full presentation marks.
• Clearly highlight base conditions and edge cases in pseudocode.
• State the final time complexity in Big-O notation at the conclusion of your answer.''';
  }

  @override
  Future<void> dispose() async {}
}
