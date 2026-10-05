import '../../core/constants/app_constants.dart';
import '../../core/utils/text_chunker.dart';
import '../../core/utils/retrieval_scorer.dart';
import '../models/topic_model.dart';
import '../models/teaching_segment_model.dart';
import '../repositories/app_repository.dart';
import 'tts_service.dart';

/// Service that analyzes user-provided study content or local documents,
/// structures it into logical classroom teaching sections, and builds
/// natural spoken scripts in English, Telugu, or Tanglish.
class ContentUnderstandingService {
  final AppRepository repository;

  ContentUnderstandingService({required this.repository});

  /// Automatically infers an appropriate topic title from study content
  /// when the student leaves the topic name blank.
  static String inferTopicTitle(String content) {
    final clean = content.trim();
    if (clean.isEmpty) return 'Study Topic';

    final lines = clean.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return 'Study Topic';

    // 1. Check for markdown headings: # Python or ## Binary Search
    for (final line in lines.take(3)) {
      final headerMatch = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(line);
      if (headerMatch != null) {
        final candidate = headerMatch.group(1)!.trim();
        if (candidate.length >= 2 && candidate.length <= 50) {
          return candidate;
        }
      }
    }

    // 2. Check for explicit prefixes like "Topic:", "Title:", "Subject:"
    for (final line in lines.take(3)) {
      final prefixMatch = RegExp(r'^(?:Topic|Title|Subject)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (prefixMatch != null) {
        final candidate = prefixMatch.group(1)!.trim();
        if (candidate.length >= 2 && candidate.length <= 50) {
          return candidate;
        }
      }
    }

    // 3. Check first line if it's short (< 40 characters) and not a full sentence
    final firstLine = lines.first;
    if (firstLine.length <= 40 && !firstLine.endsWith('.') && !firstLine.contains(',')) {
      return firstLine;
    }

    // 4. Pattern: "X is a/an ..." or "X refers to ..." or "X defined as ..."
    final defMatch = RegExp(
      r'^([A-Z][A-Za-z0-9_\s]{1,30})\s+(?:is\s+(?:an?|the)|refers\s+to|defines|means)',
      caseSensitive: true,
    ).firstMatch(clean);
    if (defMatch != null) {
      final extracted = defMatch.group(1)!.trim();
      if (extracted.isNotEmpty && extracted.length <= 40) {
        if (!extracted.toLowerCase().endsWith('programming') &&
            (extracted.toLowerCase() == 'python' || extracted.toLowerCase() == 'java' || extracted.toLowerCase() == 'c++')) {
          return '$extracted Programming';
        }
        return extracted;
      }
    }

    // 5. Look for prominent computer science keywords
    final lower = clean.toLowerCase();
    final knownKeywords = [
      'dynamic programming',
      'binary search',
      'dijkstra',
      'operating system',
      'machine learning',
      'encapsulation',
      'polymorphism',
      'inheritance',
      'data structure',
      'quick sort',
      'merge sort',
      'graph algorithm',
      'database indexing',
      'python',
      'recursion',
    ];

    for (final kw in knownKeywords) {
      if (lower.contains(kw)) {
        return kw.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
      }
    }

    // Default fallback from first words
    final words = firstLine.split(RegExp(r'\s+')).take(4).join(' ');
    return words.isNotEmpty ? words : 'Study Material';
  }

  /// Splits classroom script into logical sentence/clause speech segments
  /// for granular TTS playback tracking and exact resumption.
  static List<String> splitIntoSpeechSegments(String script) {
    if (script.trim().isEmpty) return [];

    // Split on sentence boundaries: periods, exclamation marks, question marks, and newlines
    final rawSegments = script
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .toList();

    return rawSegments.isNotEmpty ? rawSegments : [script.trim()];
  }

  /// Mode A: Topic-Only Lesson Builder
  Future<Topic?> buildLessonFromTopicOnly({
    required String topicTitle,
    required AppLanguage language,
    dynamic aiService,
  }) async {
    final cleanTitle = topicTitle.trim();
    if (cleanTitle.isEmpty) return null;

    // 1. Search existing topics in database (including pre-seeded Algorithms)
    final matchedTopic = await repository.findTopicByTitle(cleanTitle);
    if (matchedTopic != null && matchedTopic.sections.isNotEmpty) {
      final enrichedSections = matchedTopic.sections.map((s) {
        return _enrichSectionWithClassroomScript(s, language, cleanTitle);
      }).toList();

      return matchedTopic.copyWith(sections: enrichedSections);
    }

    // 2. Search local document chunks
    final allChunks = await repository.getAllChunks();
    final topChunks = RetrievalScorer.retrieveTopChunks(cleanTitle, allChunks, topK: 3);

    if (topChunks.isNotEmpty && topChunks.first.score > 0.5) {
      final combinedContent = topChunks.map((c) => c.content).join('\n\n');
      return buildLessonFromUserContent(
        topicTitle: cleanTitle,
        content: combinedContent,
        language: language,
      );
    }

    // 3. Check curated syllabus for standard educational topics
    final curatedLesson = _buildCuratedTopicLesson(cleanTitle, language);
    if (curatedLesson != null) {
      return curatedLesson;
    }

    // 4. Dynamic Fallback Structured Lesson (guarantees offline support for any subject)
    return _buildFallbackStructuredLesson(cleanTitle, language);
  }

  Topic? _buildCuratedTopicLesson(String topicTitle, AppLanguage language) {
    final lower = topicTitle.toLowerCase();
    if (lower.contains('python')) {
      return _buildPythonCuratedLesson(topicTitle, language);
    }
    if (lower.contains('api') || lower.contains('rest')) {
      return _buildApiCuratedLesson(topicTitle, language);
    }
    if (lower.contains('java') && !lower.contains('javascript')) {
      return _buildJavaCuratedLesson(topicTitle, language);
    }
    if (lower == 'c' || lower.contains('c programming') || lower.contains('c language')) {
      return _buildCCuratedLesson(topicTitle, language);
    }
    if (lower.contains('dsa') || lower.contains('data structure') || lower.contains('algorithm')) {
      return _buildDsaCuratedLesson(topicTitle, language);
    }
    if (lower.contains('dbms') || lower.contains('database') || lower.contains('sql')) {
      return _buildDbmsCuratedLesson(topicTitle, language);
    }
    if (lower.contains('operating system') || lower == 'os') {
      return _buildOsCuratedLesson(topicTitle, language);
    }
    if (lower.contains('network') || lower == 'cn') {
      return _buildNetworksCuratedLesson(topicTitle, language);
    }
    if (lower.contains('ai') || lower.contains('machine learning') || lower.contains('nlp') || lower.contains('artificial intelligence')) {
      return _buildAiMlCuratedLesson(topicTitle, language);
    }
    return null;
  }

  Topic _buildPythonCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is Python?',
        definition: 'Python is a high-level, interpreted, general-purpose programming language created by Guido van Rossum in 1991.',
        importance: 'Universally tested foundational concept in university examinations.',
        explanation: 'Python emphasizes clean code readability and simplicity. Programs run directly through an interpreter without explicit pre-compilation.',
        example: 'print("Hello, World!") executes directly with zero boilerplate code.',
        teluguExplanation: 'Python ante oka high-level, interpreted programming language. Simple syntax and readability valla software development and data science lo chala popular.',
        examPoints: '• Mention Guido van Rossum (1991).\n• State that Python is interpreted and dynamically typed.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Why Python?',
        definition: 'Python provides rapid application development with minimal lines of code compared to C, C++, or Java.',
        importance: 'Frequently tested in "Features and Advantages" 5-mark university questions.',
        explanation: 'Python reduces developer development time by 50%. Its huge standard library provides built-in tools for web, math, data analysis, and automation.',
        example: 'Swapping two variables takes one line: a, b = b, a',
        teluguExplanation: 'Python enduku use chestham ante: idi beginners ki easy ga untundi, huge standard library untundi, and rapid development ki best choice.',
        examPoints: '• Cite 4 advantages: Readability, vast standard library, cross-platform, rapid prototyping.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Features of Python',
        definition: 'Core technical attributes: simple, interpreted, dynamically typed, cross-platform, and automatic memory managed.',
        importance: 'Standard 5-mark semester exam question.',
        explanation: '1. Easy to Learn & Read: Clean English-like syntax.\n2. Dynamically Typed: No variable declarations.\n3. Platform Independent: Runs on Windows, Linux, macOS.\n4. Automatic Garbage Collection: Memory managed via reference counting.',
        example: 'Same python script runs unchanged on Linux and Windows.',
        teluguExplanation: 'Python main features: easy to learn, dynamically typed, platform independent, and automatic garbage collection.',
        examPoints: '• List the 5 key features with bullet points.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Basic Syntax & Indentation',
        definition: 'Python uses indentation (whitespace) instead of curly braces {} to define code blocks.',
        importance: 'Prevents common syntax errors and tests code hygiene.',
        explanation: 'A block of code starts with a colon (:) and must be consistently indented by 4 spaces. Missing indentation raises an IndentationError.',
        example: 'if x > 0:\n    print("Positive")',
        teluguExplanation: 'Python syntax chala clean ga untundi. Curly braces undavu, indentation use chesi code blocks ni define chestham.',
        examPoints: '• Mention colon (:) followed by 4-space indentation rule.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Variables in Python',
        definition: 'A variable is a named reference in memory used to store data values.',
        importance: 'Core building block tested in 2-mark conceptual questions.',
        explanation: 'In Python, variables are references to objects. When you assign x = 10, an integer object 10 is created in memory and x points to it.',
        example: 'x = 10; y = "Hello"',
        teluguExplanation: 'Variable ante data ni store cheyyadaniki use chese oka named location. Data type declare cheyalsina avasaram ledu.',
        examPoints: '• Explain that variables are references (pointers) to objects.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Built-in Data Types',
        definition: 'Categories of values: int, float, str, bool, list, tuple, dict, set.',
        importance: 'Tested frequently in comparison questions.',
        explanation: 'Numeric: int, float, complex.\nSequence: str, list (mutable), tuple (immutable).\nMapping: dict (key-value pairs).\nSet: set (unique unordered values).',
        example: 'num = 25; pi = 3.14; name = "Ravi"; is_active = True',
        teluguExplanation: 'Python lo built-in data types: int, float, string, boolean, list, tuple, dictionary, and set.',
        examPoints: '• Categorize mutable types (list, dict, set) vs immutable types (int, float, str, tuple).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Operators & Expressions',
        definition: 'Constructs that manipulate the values of operands.',
        importance: 'Tested in operator precedence and bitwise questions.',
        explanation: 'Arithmetic (+, -, *, /, //, %, **), Comparison (==, !=, <, >), Logical (and, or, not), Bitwise (&, |, ^), Identity (is, is not), Membership (in, not in).',
        example: 'Floor division: 7 // 2 gives 3; Exponent: 2 ** 3 gives 8.',
        teluguExplanation: 'Operators data values meeda calculations perform cheyadaniki use avthayi. Floor division // and power ** Python lo special operators.',
        examPoints: '• Highlight difference between / (float division) and // (floor division).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 7,
        title: '8. Conditional Statements',
        definition: 'Decision-making structures: if, elif, else.',
        importance: 'Essential for flow control and logic tracing.',
        explanation: 'Python evaluates boolean conditions sequentially. The first branch whose condition evaluates to True is executed.',
        example: 'if score >= 90: grade = "A"\nelif score >= 75: grade = "B"\nelse: grade = "C"',
        teluguExplanation: 'if, elif, else statements use chesi conditions check chestham. Code flow decision making meeda depend avthundi.',
        examPoints: '• Write correct syntax showing colons and indented blocks.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 8,
        title: '9. Loops: For & While',
        definition: 'Iteration structures that repeat execution of a block of code.',
        importance: 'Common 5-mark question with flowcharts.',
        explanation: 'for loop iterates over sequences (lists, strings, range). while loop executes as long as a condition remains True. break and continue control loop flow.',
        example: 'for i in range(1, 6):\n    print(i)',
        teluguExplanation: 'for loop and while loop repetitive tasks ni automate cheyadaniki use chestham. range function sequence generate chestundi.',
        examPoints: '• Explain range(start, stop, step) syntax with examples.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 9,
        title: '10. Functions & Scope',
        definition: 'A function is a reusable block of code that takes arguments and returns a value.',
        importance: 'Core structural unit of modular code tested in 5-mark and 10-mark questions.',
        explanation: 'Defined using def keyword. Supports default arguments, keyword arguments, and arbitrary arguments (*args, **kwargs). Variables defined inside are local in scope.',
        example: 'def add(a, b=10):\n    return a + b',
        teluguExplanation: 'Function anedi oka specific task ni perform cheyadaniki create chese reusable block of code. def keyword tho define chestham.',
        examPoints: '• Define positional vs default vs keyword arguments.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 10,
        title: '11. Object-Oriented Programming (OOP)',
        definition: 'Paradigm organizing code around classes (blueprints) and objects (instances).',
        importance: 'Highest scoring 10-mark question in semester exams.',
        explanation: 'Core OOP pillars: Encapsulation (data hiding), Inheritance (code reuse via superclass), Polymorphism (method overriding), and Abstraction. Python uses __init__ as the constructor.',
        example: 'class Dog:\n    def __init__(self, name):\n        self.name = name',
        teluguExplanation: 'Object Oriented Programming lo Class anedi blueprint, Object anedi real-world entity. Encapsulation and Inheritance code reuse ki use avthayi.',
        examPoints: '• Draw class diagram and explain __init__ constructor and self parameter.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 11,
        title: '12. Real-World Applications of Python',
        definition: 'Practical industry domains where Python dominates.',
        importance: 'General 5-mark essay question.',
        explanation: '1. Machine Learning & AI (TensorFlow, PyTorch)\n2. Web Development (Django, FastAPI)\n3. Data Science (Pandas, NumPy)\n4. Automation & DevOps scripting.',
        example: 'Instagram and YouTube backend services utilize Python web frameworks.',
        teluguExplanation: 'Python applications: Web development, Machine Learning, Data Analytics, Automation scripts, and AI systems.',
        examPoints: '• Cite 4 domains with popular libraries (e.g. Django, Pandas, TensorFlow).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 12,
        title: '13. Semester Exam High-Yield Points',
        definition: 'Exam blueprint for 2-mark, 5-mark, and 10-mark semester questions.',
        importance: 'Guarantees maximum scoring efficiency in university exams.',
        explanation: 'Key points:\n• 2-Mark: Define dynamic typing, List vs Tuple.\n• 5-Mark: Differentiate mutable vs immutable, explain range() and functions.\n• 10-Mark: OOP concepts with class code and inheritance hierarchy.',
        example: 'List mutable [], Tuple immutable ().',
        teluguExplanation: 'Exam point of view lo: List vs Tuple difference table, dynamic typing definition, and functions with code snippet highlight cheyali.',
        examPoints: '• List vs Tuple table.\n• Dynamic typing definition.\n• Constructor __init__ syntax.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 13,
        title: '14. Quick Revision & Summary',
        definition: 'Comprehensive summary of Python fundamentals before the exam.',
        importance: 'Rapid final review for exam preparation.',
        explanation: 'Python combines ease of learning with immense power. Master variables, sequences, functions, and OOP to score top grades.',
        example: 'def greet(name):\n    print(f"Hello {name}")',
        teluguExplanation: 'Quick revision: Python high-level interpreted language, dynamic typing, rich libraries, and simple syntax for exams.',
        examPoints: '• Revise core definitions and syntax structures.',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Python Programming Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildApiCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is an API?',
        definition: 'An API (Application Programming Interface) is a set of rules and protocols allowing different software applications to communicate with each other.',
        importance: 'Core university exam question in Web Technologies and Distributed Systems.',
        explanation: 'An API acts as a messenger that delivers your request to the server, and then returns the server response back to you.',
        example: 'A mobile weather app requests weather details from a remote meteorological server using an API.',
        teluguExplanation: 'API ante Application Programming Interface. Simple ga cheppalante, browser page ki server ki madhyalo service path la work chese interface ni API ani antaru.',
        examPoints: '• 2-Mark Question: Define API and write its full form.\n• Emphasize client-server communication mechanism.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Why Do We Need APIs?',
        definition: 'APIs eliminate redundant development by exposing modular, reusable services across systems.',
        importance: 'Frequently tested 5-mark conceptual question.',
        explanation: 'Without APIs, every app would need to build its own maps, payment gateways, and authentication systems. APIs allow separation of frontend user interfaces from backend database logic.',
        example: 'Swiggy or Uber using Google Maps API for real-time navigation instead of building their own satellite map service.',
        teluguExplanation: 'APIs enduku use chestham ante: prathi sari kotha ga code rayalsina avasaram lekunda, existing services ni connect cheyadaniki use avthundi. Example: Google Maps API or Payment Gateway.',
        examPoints: '• 3 key benefits: Reusability, security (data isolation), and platform independence.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. How APIs Work: Client-Server Architecture',
        definition: 'APIs operate on a request-response model over the network.',
        importance: 'Tested in block diagram and architecture questions.',
        explanation: 'The flow is:\nClient (Browser/App) -> API Request -> Server (Processing/DB) -> API Response -> Client Display.\nData is commonly formatted as JSON or XML.',
        example: 'Browser/App -> API -> Server -> Response',
        teluguExplanation: 'Client server ni request chestundi. Aa request ni API theesukelli server ki isthundi, server response ni malli app ki isthundi.',
        examPoints: '• Draw the 4-box architecture diagram: Client -> Request -> API/Server -> Response.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. HTTP Methods in REST APIs',
        definition: 'Standard operations defined by HTTP protocol to perform CRUD operations.',
        importance: 'Classic 5-mark and 10-mark exam question.',
        explanation: '• GET: Retrieve data from server (read-only).\n• POST: Submit new data to create a resource.\n• PUT: Update an existing resource completely.\n• DELETE: Remove a resource from the server.',
        example: 'GET /students/101 retrieves student details; POST /students creates a new student.',
        teluguExplanation: 'HTTP methods CRUD operations chestayi: GET ante data ni retrieve cheyadam, POST ante kotha data create cheyadam, PUT update cheyadam, DELETE remove cheyadam.',
        examPoints: '• Write tabular comparison of GET vs POST (Parameters in URL vs Request body, Idempotency).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. REST API Architecture & Principles',
        definition: 'Representational State Transfer (REST) is an architectural style for networked distributed systems.',
        importance: 'Highest yield 10-mark question in web technology exams.',
        explanation: '6 Architectural Constraints:\n1. Stateless: Each request contains all information needed.\n2. Client-Server separation.\n3. Cacheable responses.\n4. Uniform Interface (URIs).\n5. Layered System.\n6. Code on Demand (optional).',
        example: 'https://api.github.com/users/octocat returns user JSON payload.',
        teluguExplanation: 'REST API ante Representational State Transfer. Idi stateless ga untundi, ante server client session state ni store chesukodu. Prathi request self-contained ga untundi.',
        examPoints: '• Explain Statelessness in detail.\n• List Roy Fielding\'s 6 architectural constraints.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Practical Walkthrough: Weather API Example',
        definition: 'End-to-end example demonstrating API endpoints, query parameters, and JSON payloads.',
        importance: 'Gains full marks in illustrative code questions.',
        explanation: 'Client sends GET request: /weather?city=Hyderabad\nServer responds with JSON:\n{"city": "Hyderabad", "temp": 28, "humidity": "65%"}\nFrontend renders temperature on UI screen.',
        example: 'GET https://api.weather.com/v1/hyderabad',
        teluguExplanation: 'Example chuddam: manam weather app lo Hyderabad select chesinappudu, app weather API ni request chestundi. Server JSON format lo temperature data pampisthundi.',
        examPoints: '• Write sample JSON response snippet.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. HTTP Status Codes & Error Handling',
        definition: 'Standard 3-digit status codes indicating the outcome of the API request.',
        importance: 'Tested frequently in 2-mark and 5-mark questions.',
        explanation: '• 2xx Success: 200 OK, 201 Created.\n• 3xx Redirection: 301 Moved Permanently.\n• 4xx Client Error: 400 Bad Request, 401 Unauthorized, 404 Not Found.\n• 5xx Server Error: 500 Internal Server Error, 503 Service Unavailable.',
        example: '404 indicates the requested URL endpoint does not exist on server.',
        teluguExplanation: 'Status codes request status ni chepthayi: 200 ante success, 404 ante resource not found, 500 ante server internal error.',
        examPoints: '• Match-the-following / 2-mark definitions of 200, 401, 404, 500.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 7,
        title: '8. Semester Exam High-Yield Points',
        definition: 'Key exam blueprint for web technologies and software engineering exams.',
        importance: 'Ensures maximum scoring efficiency.',
        explanation: 'Review API definition, REST principles, GET vs POST comparison table, and HTTP status codes.',
        example: 'Exam answer template: Definition + Block Diagram + HTTP Methods + Example.',
        teluguExplanation: 'Exam lo API definition adigithe, Application Programming Interface ani mention chesi, applications madhya communication kosam use ayye interface ani rayali.',
        examPoints: '• 2-Mark: Define API.\n• 5-Mark: GET vs POST difference table.\n• 10-Mark: REST architecture and constraints with diagram.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 8,
        title: '9. Quick Revision & Summary',
        definition: 'Fast revision notes for API and REST concepts.',
        importance: 'Last-minute exam review.',
        explanation: 'APIs connect the modern web. RESTful APIs use standard HTTP verbs (GET, POST, PUT, DELETE) with JSON data format in a stateless client-server model.',
        example: 'Client -> API -> Server -> Response',
        teluguExplanation: 'Summary: API applications madhya communication bridge la work chestundi. REST API stateless and scalable.',
        examPoints: '• Revise status codes and 4 HTTP verbs.',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured API & Web Services Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildJavaCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is Java & JVM Architecture',
        definition: 'Java is a class-based, object-oriented, platform-independent language developed by James Gosling at Sun Microsystems.',
        importance: 'Guaranteed 5-mark and 10-mark exam question.',
        explanation: 'Java achieves "Write Once, Run Anywhere" (WORA) using Bytecode. The Java Virtual Machine (JVM) interprets bytecode on any operating system.',
        example: 'Java source (.java) -> javac compiler -> Bytecode (.class) -> JVM execution.',
        teluguExplanation: 'Java ante platform-independent object oriented language. JVM bytecode ni run chesi Write Once Run Anywhere feature ni enable chestundi.',
        examPoints: '• Draw JDK vs JRE vs JVM architectural diagram.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Core OOP Principles in Java',
        definition: 'Encapsulation, Inheritance, Polymorphism, and Abstraction.',
        importance: '10-mark favorite in semester exams.',
        explanation: '• Encapsulation: Binding data with methods (private fields + getters/setters).\n• Inheritance: Code reuse using extends keyword.\n• Polymorphism: Method overloading (compile-time) and method overriding (runtime).\n• Abstraction: Hiding implementation details via interfaces and abstract classes.',
        example: 'class Animal { void sound() {} }; class Dog extends Animal { void sound() { print("Bark"); } }',
        teluguExplanation: 'Java lo 4 pillars: Encapsulation (data hiding), Inheritance (extends), Polymorphism (overloading/overriding), and Abstraction (interfaces).',
        examPoints: '• Differentiate Method Overloading vs Method Overriding with code snippets.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Exception Handling in Java',
        definition: 'Mechanism to handle runtime errors so normal program flow can be maintained.',
        importance: 'Tested in 5-mark code analysis questions.',
        explanation: 'try block wraps risky code, catch handles the exception, and finally block executes unconditionally for resource cleanup.',
        example: 'try { int a = 10 / 0; } catch (ArithmeticException e) { print("Error"); } finally { print("Done"); }',
        teluguExplanation: 'try-catch-finally blocks runtime exceptions ni handle cheyadaniki use avthayi. finally block eppudu execute avthundi.',
        examPoints: '• Checked vs Unchecked exceptions comparison.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Multithreading & Concurrency',
        definition: 'Executing multiple threads simultaneously to maximize CPU utilization.',
        importance: 'Standard 5-mark conceptual question.',
        explanation: 'Threads can be created by extending Thread class or implementing Runnable interface. synchronized keyword prevents race conditions.',
        example: 'class MyThread extends Thread { public void run() { print("Running"); } }',
        teluguExplanation: 'Multithreading valla CPU parallel tasks ni execute chestundi. Runnable interface or Thread class extend chesi create chestham.',
        examPoints: '• Life cycle of a Thread diagram (New, Runnable, Running, Blocked, Terminated).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Java Collections Framework',
        definition: 'Unified architecture for representing and manipulating collections of objects.',
        importance: 'Tested in university exams and tech interviews.',
        explanation: 'Core interfaces: List (ArrayList, LinkedList), Set (HashSet, TreeSet), Map (HashMap, TreeMap).',
        example: 'List<String> list = new ArrayList<>(); list.add("Java");',
        teluguExplanation: 'Collections framework data structures ni ready-made ga provide chestundi: ArrayList, HashSet, HashMap.',
        examPoints: '• ArrayList vs LinkedList comparison table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points for scoring full marks.',
        importance: 'High-speed revision notes.',
        explanation: 'Review JVM architecture diagram, OOP 4 pillars with code snippets, String vs StringBuffer, and Exception hierarchy.',
        example: 'String is immutable; StringBuffer is mutable and thread-safe.',
        teluguExplanation: 'Exam lo JVM diagram, OOP concepts with code snippets, and String vs StringBuffer comparison table tappakunda rayali.',
        examPoints: '• JVM Diagram.\n• Overloading vs Overriding.\n• String vs StringBuffer.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Wrap-up of Java exam preparation.',
        importance: 'Last-minute review.',
        explanation: 'Java enforces strong object-oriented principles, garbage collection, and platform independence via JVM bytecode.',
        example: 'public static void main(String[] args)',
        teluguExplanation: 'Summary: Java robust, secure, platform independent language for enterprise applications.',
        examPoints: '• Revise access modifiers (public, private, protected, default).',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Java Programming Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildCCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is C Programming & Structure',
        definition: 'C is a general-purpose, procedural, middle-level programming language created by Dennis Ritchie in 1972 at Bell Labs.',
        importance: 'Foundational first-year B.Tech engineering course.',
        explanation: 'C combines high-level structured programming with low-level direct memory manipulation using pointers.',
        example: '#include <stdio.h>\nint main() { printf("Hello"); return 0; }',
        teluguExplanation: 'C language Dennis Ritchie develop chesina procedural language. Idi memory pointers tho direct access ivvadam valla middle-level language antaru.',
        examPoints: '• Mention Dennis Ritchie (1972, Bell Labs).\n• Structure of a C program diagram.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Pointers & Memory Addresses',
        definition: 'A pointer is a variable that stores the memory address of another variable.',
        importance: 'Guaranteed 5-mark and 10-mark question.',
        explanation: '& is address-of operator; * is dereference operator. Pointers enable call by reference and dynamic memory allocation.',
        example: 'int x = 10; int *ptr = &x; printf("%d", *ptr);',
        teluguExplanation: 'Pointer ante inko variable memory address ni store chesukune special variable. & address ni isthundi, * value ni retrieve chestundi.',
        examPoints: '• Explain pointer declaration, initialization, and dereferencing with diagram.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Dynamic Memory Allocation (DMA)',
        definition: 'Allocating memory at runtime from heap memory using malloc(), calloc(), realloc(), and free().',
        importance: 'Classic 5-mark semester question.',
        explanation: '• malloc(size): allocates uninitialized bytes.\n• calloc(n, size): allocates zero-initialized elements.\n• free(ptr): deallocates memory to prevent memory leaks.',
        example: 'int *arr = (int*) malloc(5 * sizeof(int)); free(arr);',
        teluguExplanation: 'Runtime lo memory allocate cheyadaniki malloc and calloc use chestham. Memory leak avvakunda free() call cheyali.',
        examPoints: '• malloc vs calloc difference table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Structures & Unions',
        definition: 'User-defined data types grouping different data types under one name.',
        importance: 'Frequently tested 5-mark comparison question.',
        explanation: 'In Structure, each member gets its own separate memory. In Union, all members share the same single memory location (size equal to largest member).',
        example: 'struct Student { int roll; char name[20]; };',
        teluguExplanation: 'Structure lo prathi member ki separate memory untundi. Union lo anni members oke memory space ni share chesukuntayi.',
        examPoints: '• Tabular comparison of Structure vs Union memory allocation.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Functions & Recursion in C',
        definition: 'Modular blocks of code. Call by value vs call by reference.',
        importance: 'Core 5-mark question with code trace.',
        explanation: 'Call by value copies actual parameter values; call by reference passes memory addresses allowing original values to be modified.',
        example: 'void swap(int *a, int *b) { int temp = *a; *a = *b; *b = temp; }',
        teluguExplanation: 'Functions reusable code blocks. Call by reference lo pointers pass chestham kabatti original variables change avthayi.',
        examPoints: '• Write swap two numbers program using call by reference.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points.',
        importance: 'High-speed revision.',
        explanation: 'Review Call by Value vs Call by Reference, Structure vs Union, malloc vs calloc, and pointer arithmetic.',
        example: 'ptr++ advances pointer by sizeof(datatype) bytes.',
        teluguExplanation: 'Exam lo pointers diagram, Call by value vs reference table, and malloc vs calloc tappakunda rayali.',
        examPoints: '• Structure vs Union table.\n• Call by value vs reference.\n• Pointer syntax.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Recap of C programming concepts.',
        importance: 'Final wrap-up.',
        explanation: 'C provides direct control over hardware and memory, forming the foundation of operating systems and embedded programming.',
        example: 'return 0 indicates successful execution.',
        teluguExplanation: 'Summary: C language efficient, low-level memory control unna foundational language.',
        examPoints: '• Revise storage classes (auto, register, static, extern).',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured C Programming Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildDsaCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What are Data Structures & Classification',
        definition: 'A data structure is a specialized format for organizing, processing, retrieving, and storing data in computer memory efficiently.',
        importance: 'Foundational topic across university exams and technical interviews.',
        explanation: 'Classified into:\n1. Linear: Arrays, Linked Lists, Stacks, Queues (elements sequentially adjacent).\n2. Non-Linear: Trees, Graphs (hierarchical and interconnected).',
        example: 'Arrays store data in contiguous memory; Linked lists use pointers.',
        teluguExplanation: 'Data structure ante data ni memory lo efficient ga store chesi retrieve chese way. Linear (Arrays, Stacks) and Non-linear (Trees, Graphs) ga divide chestham.',
        examPoints: '• Classification tree diagram: Linear vs Non-Linear, Static vs Dynamic.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Stacks: LIFO Principle & Applications',
        definition: 'A stack is a linear data structure following Last-In-First-Out (LIFO) order.',
        importance: '5-mark question with infix-to-postfix conversion.',
        explanation: 'Key operations: push(x), pop(), peek(). All operations execute in O(1) time complexity. Applications: Function call stack, undo operations, parenthesis matching.',
        example: 'A stack of plates: the plate added last is removed first.',
        teluguExplanation: 'Stack Last In First Out (LIFO) follow avthundi. Push ante insert, Pop ante delete. Call stack and undo mechanism lo use avthundi.',
        examPoints: '• Infix to Postfix conversion steps.\n• Algorithm for balanced parenthesis check.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Queues: FIFO Principle & Variants',
        definition: 'A queue is a linear data structure following First-In-First-Out (FIFO) order.',
        importance: 'Common 5-mark and 10-mark question.',
        explanation: 'Insertion at Rear (enqueue), deletion at Front (dequeue). Variants: Circular Queue (eliminates memory wastage), Priority Queue, Deque.',
        example: 'People standing in a ticket counter queue.',
        teluguExplanation: 'Queue First In First Out (FIFO) follow avthundi. Circular queue memory waste avvakunda wrap-around logic use chestundi.',
        examPoints: '• Write circular queue full and empty conditions: (rear + 1) % size == front.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Linked Lists: Singly, Doubly, Circular',
        definition: 'A dynamic linear data structure composed of nodes, where each node contains data and pointer(s) to subsequent nodes.',
        importance: 'Core 10-mark question on node insertion and deletion.',
        explanation: 'Unlike arrays, linked lists do not require contiguous memory allocation. Dynamic size, O(1) insertion at head, but O(n) sequential search.',
        example: 'Node: [Data | Next Pointer] -> [Data | Next Pointer] -> NULL',
        teluguExplanation: 'Linked list nodes tho form avthundi. Prathi node lo data and next node pointer untayi. Dynamic ga memory grow avthundi.',
        examPoints: '• Arrays vs Linked Lists comparison table.\n• Algorithm for inserting node at beginning and end.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Trees & Binary Search Trees (BST)',
        definition: 'A hierarchical non-linear data structure with a root node and subtrees.',
        importance: 'Frequently tested 10-mark question.',
        explanation: 'In BST, for every node: left subtree keys < node key < right subtree keys. Tree traversals: Inorder (Left-Root-Right, gives sorted order), Preorder, Postorder.',
        example: 'Inorder traversal of BST always produces ascending sorted output.',
        teluguExplanation: 'Tree non-linear hierarchical data structure. Binary Search Tree lo left child small ga, right child peddadi ga untundi. Inorder traversal sorted order istundi.',
        examPoints: '• Inorder, Preorder, Postorder traversal algorithm and trace.\n• BST search complexity O(log n) average, O(n) worst-case.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Graphs & Traversal: BFS vs DFS',
        definition: 'Non-linear data structure consisting of vertices V and edges E connecting pairs of vertices.',
        importance: 'Classic 10-mark algorithm question.',
        explanation: '• Breadth-First Search (BFS): Level-by-level traversal using a Queue. Time O(V + E).\n• Depth-First Search (DFS): Deep branch traversal using Recursion/Stack. Time O(V + E).',
        example: 'Shortest path in unweighted graph solved using BFS.',
        teluguExplanation: 'Graph vertices and edges tho untundi. BFS queue use chesi level-by-level traverse chestundi; DFS stack use chesi depth lo traverse chestundi.',
        examPoints: '• BFS vs DFS comparison table.\n• Adjacency Matrix vs Adjacency List representation.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Semester Exam High-Yield Points',
        definition: 'High-scoring exam revision.',
        importance: 'Maximum scoring efficiency.',
        explanation: 'Review Big-O complexities for all operations across Array, LinkedList, Stack, Queue, BST, and Heap.',
        example: 'Binary search: O(log n); Quick sort: O(n log n).',
        teluguExplanation: 'Exam lo time complexities table, BFS vs DFS comparison, and Infix to Postfix trace tappakunda rayali.',
        examPoints: '• Infix to Postfix.\n• BST insertion.\n• Time complexity summary table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 7,
        title: '8. Quick Revision & Summary',
        definition: 'Final summary of Data Structures.',
        importance: 'Wrap-up before tests.',
        explanation: 'Choosing the optimal data structure depends on access patterns: Arrays for direct indexing, Trees for hierarchical searching, Hash tables for instant lookup.',
        example: 'Hash map provides O(1) average lookup.',
        teluguExplanation: 'Summary: Right data structure pick chesthe application performance and scalability optimize avthundi.',
        examPoints: '• Revise LIFO, FIFO, and BST property.',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Data Structures & Algorithms Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildDbmsCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is DBMS & Architecture',
        definition: 'A Database Management System (DBMS) is software that manages, stores, and retrieves structured data efficiently and securely.',
        importance: 'Foundational 5-mark question in university DBMS papers.',
        explanation: 'Three-Schema Architecture: Physical level (how data is stored), Logical level (what data is stored), and View level (user views). Provides physical and logical data independence.',
        example: 'MySQL, PostgreSQL, Oracle.',
        teluguExplanation: 'DBMS ante data ni structured ga store chesi, secure ga manage chese software. 3-level architecture data independence provide chestundi.',
        examPoints: '• 3-Level Architecture diagram.\n• Physical vs Logical Data Independence.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Relational Model & Keys',
        definition: 'Data organized into 2D tables (relations) with rows (tuples) and columns (attributes).',
        importance: 'Core 5-mark question on database integrity.',
        explanation: 'Key types:\n• Primary Key: Unique, non-null identifier.\n• Candidate Key: Minimal super key.\n• Foreign Key: Refers to primary key of another table, ensuring referential integrity.',
        example: 'student_id is Primary Key in Students table; dept_id is Foreign Key referencing Department table.',
        teluguExplanation: 'Relational model lo data tables రూపంలో store avthundi. Primary Key unique ga records ni identify chestundi, Foreign Key relations create chestundi.',
        examPoints: '• Define Primary Key, Foreign Key, Candidate Key, and Super Key.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. ACID Properties in Transactions',
        definition: 'The four fundamental properties ensuring reliable transaction processing in database systems.',
        importance: 'Universally tested 5-mark and 10-mark semester exam question.',
        explanation: '• Atomicity: All or nothing execution.\n• Consistency: Database transitions between valid states.\n• Isolation: Concurrent transactions do not interfere with each other.\n• Durability: Committed updates survive system crashes.',
        example: 'Bank transfer: Deducting money from Account A and adding to Account B must be atomic.',
        teluguExplanation: 'ACID properties: Atomicity (all or nothing), Consistency (rules follow avvali), Isolation (concurrent safe), Durability (crash aina data safe).',
        examPoints: '• Detail all 4 properties with bank transaction example.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Normalization: 1NF, 2NF, 3NF, BCNF',
        definition: 'Systematic technique of organizing database tables to reduce data redundancy and eliminate anomalies.',
        importance: 'Highest scoring 10-mark question in DBMS examinations.',
        explanation: '• 1NF: Atomic values (no repeating groups).\n• 2NF: In 1NF and no partial dependencies (all non-key attributes fully dependent on candidate key).\n• 3NF: In 2NF and no transitive dependencies (X -> Y, Y -> Z eliminated).\n• BCNF: Stricter 3NF where for every functional dependency X -> Y, X must be a super key.',
        example: 'Decomposing Student_Course table to eliminate update and deletion anomalies.',
        teluguExplanation: 'Normalization data redundancy (duplicates) and anomalies ni eliminate chestundi: 1NF atomic values, 2NF no partial dependency, 3NF no transitive dependency.',
        examPoints: '• Step-by-step normalization problem with functional dependencies.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. SQL Queries & Joins',
        definition: 'Structured Query Language operations: DDL, DML, DCL, and Joins.',
        importance: 'Practical 5-mark and 10-mark query writing questions.',
        explanation: 'Joins combine rows from two or more tables:\n• INNER JOIN: Matching rows in both tables.\n• LEFT JOIN: All rows from left table + matching from right.\n• RIGHT JOIN: All rows from right table + matching from left.\n• FULL JOIN: All rows when match in either.',
        example: 'SELECT S.name, C.course FROM Students S JOIN Courses C ON S.course_id = C.id;',
        teluguExplanation: 'SQL data query cheyadaniki standard language. Joins use chesi multiple tables madhya data ni match chesi combine chestham.',
        examPoints: '• Write SQL queries for INNER JOIN and GROUP BY with HAVING clause.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points.',
        importance: 'High-speed revision.',
        explanation: 'Review ACID properties, ER Diagram notations, Normalization definitions (1NF-BCNF), and File System vs DBMS differences.',
        example: 'DBMS avoids data redundancy and concurrency problems inherent in file systems.',
        teluguExplanation: 'Exam lo ACID properties, Normalization 1NF to BCNF definitions, and ER diagram notations tappakunda prepare avvali.',
        examPoints: '• ACID properties.\n• Normalization rules.\n• DBMS vs File System.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Wrap-up of DBMS.',
        importance: 'Final review.',
        explanation: 'DBMS guarantees data integrity, concurrency control via 2-Phase Locking, and crash recovery using write-ahead logs.',
        example: 'COMMIT saves transaction permanently.',
        teluguExplanation: 'Summary: DBMS enterprise data safety, fast query execution, and relational integrity ensure chestundi.',
        examPoints: '• Revise Primary key vs Unique key.',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Database Management Systems Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildOsCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is an Operating System & Functions',
        definition: 'An Operating System (OS) is system software acting as an intermediary between computer hardware and user applications.',
        importance: 'Foundational 5-mark question in OS papers.',
        explanation: 'Core functions: Process management, Memory management, File system management, Device I/O handling, and Protection/Security.',
        example: 'Linux, Windows, Android, macOS.',
        teluguExplanation: 'Operating System user ki computer hardware ki madhyalo bridge la work chestundi. CPU, Memory, and Storage ni manage chestundi.',
        examPoints: '• 5 core OS functions with one line each.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Process vs Thread',
        definition: 'A process is a program in execution with separate address space; a thread is a lightweight process sharing memory with peers.',
        importance: 'Guaranteed 5-mark comparison table question.',
        explanation: 'Processes have heavy context switching overhead and isolated memory. Threads share code, data, and OS resources, resulting in fast context switching.',
        example: 'A browser is a process; individual tabs or download threads are threads within it.',
        teluguExplanation: 'Process ante running program (separate memory). Thread ante process loni lightweight unit (shared memory). Context switching threads lo chala fast.',
        examPoints: '• Process vs Thread 4-point comparison table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. CPU Scheduling Algorithms',
        definition: 'Algorithms determining which ready process is allocated the CPU by the short-term scheduler.',
        importance: 'Classic 10-mark numerical question with Gantt Chart.',
        explanation: '• FCFS (First Come First Serve): Non-preemptive, Convoy effect.\n• SJF (Shortest Job First): Optimal average waiting time.\n• Round Robin (RR): Time quantum based, fair and preemptive.\n• Priority Scheduling: Higher priority executes first.',
        example: 'Round Robin with time quantum = 2ms.',
        teluguExplanation: 'CPU scheduling algorithms ready processes ki CPU time allocate chestayi: FCFS, SJF, and Round Robin time quantum tho work avthundi.',
        examPoints: '• Solve Gantt chart problem calculating Average Waiting Time and Turnaround Time.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Deadlocks: 4 Necessary Conditions',
        definition: 'A deadlock occurs when a set of processes are blocked because each holds a resource and waits for another resource held by another process.',
        importance: 'Highest scoring 10-mark question in OS.',
        explanation: 'Coffman\'s 4 Conditions:\n1. Mutual Exclusion: At least 1 non-shareable resource.\n2. Hold and Wait: Process holding a resource waits for another.\n3. No Preemption: Resources cannot be forcibly seized.\n4. Circular Wait: A closed chain of processes waiting circularly.',
        example: 'Two trains approaching each other on a single track.',
        teluguExplanation: 'Deadlock lo processes resources kosam wait chestu freeze avthayi. 4 conditions: Mutual Exclusion, Hold & Wait, No Preemption, and Circular Wait.',
        examPoints: '• State Coffman\'s 4 conditions clearly.\n• Explain Banker\'s Algorithm for Deadlock Avoidance.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Virtual Memory & Paging',
        definition: 'Memory management scheme separating logical address space from physical memory.',
        importance: '10-mark question with page replacement algorithms.',
        explanation: 'Logical memory divided into Pages; physical memory divided into Frames. Page Table maps pages to frames. When requested page is not in RAM, a Page Fault occurs. Algorithms: FIFO, LRU, Optimal.',
        example: 'LRU (Least Recently Used) replaces the page that has not been used for longest time.',
        teluguExplanation: 'Virtual memory RAM kante pedda programs ni run cheyadaniki help chestundi. Paging mechanism pages ni frames ki map chestundi. Page fault aithe disk nundi page thestham.',
        examPoints: '• Solve LRU Page Replacement numerical calculating page fault ratio.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points.',
        importance: 'High-speed revision.',
        explanation: 'Review Gantt chart calculation, Deadlock 4 conditions, Banker\'s Algorithm safety check, and LRU page replacement.',
        example: 'Turnaround Time = Completion Time - Arrival Time.',
        teluguExplanation: 'Exam lo Gantt Chart calculation, Coffman 4 conditions, and LRU page replacement numericals compulsory ga vastayi.',
        examPoints: '• Gantt Chart calculation.\n• 4 Deadlock conditions.\n• LRU Page Replacement.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Recap of Operating Systems.',
        importance: 'Final review.',
        explanation: 'Operating Systems coordinate memory, processes, storage, and I/O to deliver safety, fairness, and performance.',
        example: 'Kernel executes in privileged supervisor mode.',
        teluguExplanation: 'Summary: OS resource manager la work chesi multitasking and process synchronization ensure chestundi.',
        examPoints: '• Revise User mode vs Kernel mode.',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Operating Systems Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildNetworksCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. OSI 7-Layer Model Architecture',
        definition: 'Open Systems Interconnection (OSI) conceptual reference model for network communications.',
        importance: 'Guaranteed 10-mark semester exam question.',
        explanation: '7 Layers (Top to Bottom):\n7. Application (HTTP, DNS)\n6. Presentation (Encryption)\n5. Session (Session sync)\n4. Transport (TCP, UDP, segments)\n3. Network (IP, packets, routing)\n2. Data Link (Ethernet, frames, MAC)\n1. Physical (Bits, cables, signals).',
        example: 'Mnemonic: "All People Seem To Need Data Processing".',
        teluguExplanation: 'OSI 7 layers model: Application, Presentation, Session, Transport, Network, Data Link, and Physical layers network data transmission ni divide chestayi.',
        examPoints: '• Draw 7-layer diagram and explain functions of Transport and Network layers.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. TCP vs UDP Protocols',
        definition: 'Transport layer protocols: TCP is connection-oriented and reliable; UDP is connectionless and fast.',
        importance: 'Classic 5-mark comparison table.',
        explanation: '• TCP: 3-Way Handshake (SYN, SYN-ACK, ACK), error checking, flow control, retransmission. Used in Web, Email, File transfer.\n• UDP: No handshake, lightweight, no delivery guarantee. Used in Video streaming, Gaming, DNS.',
        example: 'YouTube streaming uses UDP for latency; banking transactions use TCP for reliability.',
        teluguExplanation: 'TCP reliable and connection-oriented (3-way handshake). UDP connectionless and fast (streaming and live gaming lo use chestham).',
        examPoints: '• TCP vs UDP 5-point comparison table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. IP Addressing & Subnetting',
        definition: 'Logical addressing scheme: IPv4 (32-bit) vs IPv6 (128-bit) and Classless Inter-Domain Routing (CIDR).',
        importance: 'Tested in 5-mark numerical subnetting questions.',
        explanation: 'IPv4 format: 4 octets (e.g., 192.168.1.1). Subnet mask separates Network ID from Host ID. CIDR notation /24 indicates 24 network bits.',
        example: '192.168.1.0/24 supports 254 usable host addresses.',
        teluguExplanation: 'IP address network lo devices ni identify chestundi. IPv4 32-bit, IPv6 128-bit. Subnetting network ni smaller parts ga divide chestundi.',
        examPoints: '• IPv4 vs IPv6 comparison.\n• Calculate usable hosts given CIDR mask.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Routing Algorithms: Distance Vector vs Link State',
        definition: 'Algorithms finding the shortest optimal path across routers.',
        importance: '10-mark algorithm question.',
        explanation: '• Distance Vector (Bellman-Ford): Exchanges routing tables with immediate neighbors. Suffers from count-to-infinity problem.\n• Link State (Dijkstra): Floods complete network topology to all routers and computes shortest path tree.',
        example: 'OSPF uses Dijkstra Link State; RIP uses Distance Vector.',
        teluguExplanation: 'Routing algorithms shortest path find chestayi: Distance Vector neighbors tho tables share chestundi; Link State Dijkstra algorithm use chesi shortest path tree compute chestundi.',
        examPoints: '• Compare Distance Vector vs Link State.\n• Solve Dijkstra algorithm step-by-step.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. DNS & HTTP/HTTPS Protocols',
        definition: 'Application layer protocols enabling modern web browsing.',
        importance: 'Frequently tested 5-mark conceptual question.',
        explanation: '• DNS (Domain Name System): Resolves human-readable domain names (google.com) to IP addresses (142.250.190.46) on UDP port 53.\n• HTTP/HTTPS: Hypertext Transfer Protocol. HTTPS adds TLS/SSL encryption over port 443.',
        example: 'Typing google.com triggers DNS lookup, followed by TLS handshake, then HTTP GET.',
        teluguExplanation: 'DNS domain names ni IP addresses ga convert chestundi. HTTPS TLS encryption tho secure browsing provide chestundi.',
        examPoints: '• Explain DNS resolution steps from browser cache to root nameserver.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points.',
        importance: 'High-speed revision.',
        explanation: 'Review OSI 7-layer functions, TCP 3-way handshake diagram, TCP vs UDP table, and Dijkstra routing trace.',
        example: 'SYN -> SYN-ACK -> ACK.',
        teluguExplanation: 'Exam lo OSI 7 layers diagram, TCP vs UDP comparison, and DNS resolution steps compulsory questions.',
        examPoints: '• OSI Model Diagram.\n• TCP 3-Way Handshake.\n• TCP vs UDP table.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Recap of Computer Networks.',
        importance: 'Final wrap-up.',
        explanation: 'Computer Networks establish reliable, high-throughput communication across heterogeneous physical media using layered protocols.',
        example: 'Routers operate at Network Layer (Layer 3); Switches operate at Data Link Layer (Layer 2).',
        teluguExplanation: 'Summary: Computer Networks layered protocols tho global communication and data sharing enable chestundi.',
        examPoints: '• Revise Router (Layer 3) vs Switch (Layer 2).',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured Computer Networks Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildAiMlCuratedLesson(String topicTitle, AppLanguage language) {
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is AI & Machine Learning Overview',
        definition: 'Artificial Intelligence (AI) is the simulation of human intelligence by machines. Machine Learning (ML) is a subset of AI that learns patterns from data without explicit programming.',
        importance: 'Core introductory question in AI semester examinations.',
        explanation: 'AI encompasses rule-based systems, expert systems, and ML. ML algorithms improve performance on a task T with experience E measured by metric P.',
        example: 'Spam email filter learning to classify spam based on historical labeled emails.',
        teluguExplanation: 'AI ante machines ki human-like intelligence ivvadam. Machine Learning lo data nundi patterns nerchukoni predictions chestam, explicit rules rayalsina avasaram ledu.',
        examPoints: '• Define AI vs ML vs Deep Learning with nested Venn diagram.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Supervised, Unsupervised & Reinforcement Learning',
        definition: 'The three primary paradigms of Machine Learning.',
        importance: 'Guaranteed 5-mark and 10-mark comparison question.',
        explanation: '• Supervised: Labeled data (Input X + Target Y). Tasks: Classification, Regression. (e.g., Linear Regression, Decision Trees).\n• Unsupervised: Unlabeled data (Input X only). Tasks: Clustering, Dimensionality reduction. (e.g., K-Means, PCA).\n• Reinforcement: Agent interacts with environment via actions, receiving rewards or penalties. (e.g., Q-Learning, self-driving cars).',
        example: 'Predicting house prices from features is Supervised; Customer segmentation is Unsupervised.',
        teluguExplanation: 'Supervised lo labeled data untundi (questions + answers). Unsupervised lo patterns ni automatic ga cluster chestam. Reinforcement lo rewards and penalties tho agent nerchukuntundi.',
        examPoints: '• 3-column comparison table: Data type, Objective, Canonical algorithms.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Regression vs Classification',
        definition: 'The two foundational tasks of supervised learning.',
        importance: '5-mark conceptual question.',
        explanation: '• Regression: Predicts continuous numerical values (e.g., temperature, stock price). Metric: Mean Squared Error (MSE).\n• Classification: Predicts discrete categorical labels (e.g., Yes/No, Cat/Dog). Metric: Accuracy, Precision, Recall, F1-Score.',
        example: 'Predicting student exam marks (0-100) is Regression; predicting Pass/Fail is Classification.',
        teluguExplanation: 'Regression continuous numbers predict chestundi (house price, temperature). Classification discrete categories predict chestundi (Pass or Fail, Spam or Not Spam).',
        examPoints: '• Differentiate Regression vs Classification with metrics (MSE vs Accuracy/F1).',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Neural Networks & Deep Learning Basics',
        definition: 'Computational models inspired by biological neural networks in the human brain.',
        importance: '10-mark question on Perceptrons and Multi-Layer Perceptrons (MLP).',
        explanation: 'Consists of Input Layer, Hidden Layers, and Output Layer. Nodes apply weights, biases, and non-linear activation functions (ReLU, Sigmoid). Trained via Backpropagation with Gradient Descent.',
        example: 'Image recognition identifying handwritten digits (MNIST dataset).',
        teluguExplanation: 'Neural networks brain neurons laaga work chestayi. Weights and biases adjust cheskuntu backpropagation algorithm tho accurate ga predict chestayi.',
        examPoints: '• Single layer Perceptron diagram with activation function formula.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Natural Language Processing (NLP) Overview',
        definition: 'Branch of AI enabling computers to understand, interpret, and generate human language.',
        importance: '5-mark question in AI/ML papers.',
        explanation: 'Key stages: Tokenization, Stemming/Lemmatization, Stop-word removal, POS Tagging, Word Embeddings (Word2Vec), and Transformer models (BERT, GPT).',
        example: 'Sentiment analysis determining whether a movie review is positive or negative.',
        teluguExplanation: 'NLP human language ni understand cheyadaniki use avthundi. Tokenization words ga divide chestundi, sentiment analysis emotion ni detect chestundi.',
        examPoints: '• List text preprocessing pipeline steps in order.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Semester Exam High-Yield Points',
        definition: 'Key exam focus points.',
        importance: 'High-speed revision.',
        explanation: 'Review Supervised vs Unsupervised comparison, Overfitting vs Underfitting (Bias-Variance tradeoff), and Evaluation metrics (Precision, Recall, ROC-AUC).',
        example: 'Overfitting occurs when model memorizes training noise and fails on test data.',
        teluguExplanation: 'Exam lo Supervised vs Unsupervised table, Bias-Variance tradeoff, and Overfitting vs Underfitting compulsory questions.',
        examPoints: '• Supervised vs Unsupervised table.\n• Overfitting vs Underfitting.\n• Precision and Recall formulas.',
        language: language,
        topicTitle: topicTitle,
      ),
      _createSection(
        topicId: 0,
        order: 6,
        title: '7. Quick Revision & Summary',
        definition: 'Recap of AI and ML fundamentals.',
        importance: 'Final review.',
        explanation: 'AI and ML transform raw data into intelligent autonomous decisions through data preprocessing, model training, validation, and continuous evaluation.',
        example: 'Train-Test split (80% train, 20% test).',
        teluguExplanation: 'Summary: ML data driven predictions provide chestundi, right model evaluation top results ni guarantee chestundi.',
        examPoints: '• Revise Confusion Matrix components (TP, FP, TN, FN).',
        language: language,
        topicTitle: topicTitle,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: topicTitle,
      summary: 'Structured AI & Machine Learning Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  Topic _buildFallbackStructuredLesson(String topicTitle, AppLanguage language) {
    final clean = topicTitle.trim();
    final sections = <LessonSection>[
      _createSection(
        topicId: 0,
        order: 0,
        title: '1. What is $clean & Foundational Concept',
        definition: '$clean is an essential core concept in computer science and engineering curricula.',
        importance: 'Universal semester exam topic tested for conceptual understanding.',
        explanation: 'Let us understand the core idea of $clean. It defines clear computational principles, rules, and methodologies for solving engineering problems efficiently.',
        example: 'In practical applications, $clean processes inputs systematically to produce reliable, deterministic outputs.',
        teluguExplanation: '$clean ante oka important engineering concept. Simple ga cheppalante, systems lo problems ni systematically solve cheyadaniki idi use avthundi.',
        examPoints: '• State the primary definition in 2 clear lines.\n• Highlight the foundational keyword.',
        language: language,
        topicTitle: clean,
      ),
      _createSection(
        topicId: 0,
        order: 1,
        title: '2. Why We Need $clean',
        definition: 'Key engineering motivation and problems solved by $clean.',
        importance: 'Helps students answer "Need and Scope" questions in exams.',
        explanation: 'Without $clean, implementations become unorganized, computationally expensive, and fragile. Applying $clean ensures modularity, optimal resource utilization, and maintainability.',
        example: 'Reduces operational overhead and ensures structured execution across systems.',
        teluguExplanation: '$clean enduku use chestham ante: idi systems efficiency ni increase chestundi, errors ni reduce chestundi, and maintainability ni improve chestundi.',
        examPoints: '• List 3 distinct engineering advantages.\n• Contrast with naive ad-hoc approaches.',
        language: language,
        topicTitle: clean,
      ),
      _createSection(
        topicId: 0,
        order: 2,
        title: '3. Core Working Principles & Mechanics',
        definition: 'Governing rules, step-by-step logic, and architecture of $clean.',
        importance: 'Frequently tested in 5-mark and 10-mark technical questions.',
        explanation: 'Let us break down the exact mechanism of $clean:\n1. Input Specification: Defined parameters and constraints.\n2. Processing Logic: Systematic deterministic steps.\n3. Output State: Verified and consistent final results.',
        example: 'Trace the progression from initial input conditions to final verified output.',
        teluguExplanation: '$clean working principles lo: input validation, core processing logic, and expected output untayi. Prathi step deterministic ga execute avthundi.',
        examPoints: '• Draw block diagrams neatly with labeled inputs, process blocks, and outputs.',
        language: language,
        topicTitle: clean,
      ),
      _createSection(
        topicId: 0,
        order: 3,
        title: '4. Practical Example & Working Walkthrough',
        definition: 'Illustrative real-world case study explaining $clean.',
        importance: 'Earns top presentation marks in university examinations.',
        explanation: 'Let us see a concrete scenario for $clean: Consider a standard engineering system processing tasks under real-world constraints. By applying $clean, the system guarantees correctness and scalability.',
        example: 'Standard real-world scenario demonstrating input processing and output verification.',
        teluguExplanation: 'Example chuddam: real-world scenario lo $clean ela work avthundo step-by-step ga trace chesthe concept chala easy ga artham avthundi.',
        examPoints: '• Always include an illustrative example to secure full marks.',
        language: language,
        topicTitle: clean,
      ),
      _createSection(
        topicId: 0,
        order: 4,
        title: '5. Semester Exam High-Yield Points',
        definition: 'Blueprint for answering 2-mark, 5-mark, and 10-mark semester questions.',
        importance: 'Maximum scoring efficiency in university exams.',
        explanation: '• 2-Mark: State the standard definition and list 1 key property.\n• 5-Mark: Draw a neat architectural diagram and explain 4 core principles with a short example.\n• 10-Mark: Full derivation, comparative trade-offs, and step-by-step walkthrough.',
        example: 'Write structured headings and bullet points on the answer paper.',
        teluguExplanation: 'Exam point of view lo idi chala important: 2-marks ki concise definition, 5-marks ki diagram + example, and 10-marks ki complete in-depth analysis rayali.',
        examPoints: '• 2-Mark: Define $clean.\n• 5-Mark: Explain working with diagram.\n• 10-Mark: Comprehensive architecture and comparison.',
        language: language,
        topicTitle: clean,
      ),
      _createSection(
        topicId: 0,
        order: 5,
        title: '6. Quick Revision & Summary',
        definition: 'Key takeaways and revision notes for $clean.',
        importance: 'Last-minute recap before exam.',
        explanation: 'To recap $clean:\n1. Core definition and primary purpose.\n2. Architectural components and working principles.\n3. Best practices and exam presentation guidelines.',
        example: 'Review bullet points and formulas before entering the exam hall.',
        teluguExplanation: 'Summary: $clean foundational principles, core working mechanism, and exam scoring points ni gurthunchukovadam chala important.',
        examPoints: '• Revise core definitions and keywords.',
        language: language,
        topicTitle: clean,
      ),
    ];

    return Topic(
      id: null,
      subjectId: 0,
      title: clean,
      summary: 'Structured $clean Lesson',
      orderIndex: 0,
      sections: sections,
    );
  }

  /// Mode B: Topic + User-Provided Content
  /// The user's content is the PRIMARY SOURCE.
  Topic buildLessonFromUserContent({
    String? topicTitle,
    required String content,
    required AppLanguage language,
  }) {
    final cleanText = TextChunker.cleanText(content);
    if (cleanText.isEmpty) {
      throw ArgumentError('Study content cannot be empty.');
    }

    // Infer topic if not provided
    final resolvedTopic = (topicTitle != null && topicTitle.trim().isNotEmpty)
        ? topicTitle.trim()
        : inferTopicTitle(cleanText);

    // Split paragraphs
    final paragraphs = cleanText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Identify key sentences and components
    final definitions = <String>[];
    final examples = <String>[];
    final formulas = <String>[];
    final keyPoints = <String>[];

    for (final p in paragraphs) {
      final lower = p.toLowerCase();
      if (lower.contains('defined as') ||
          lower.contains('is a ') ||
          lower.contains('means ') ||
          lower.contains('definition') ||
          lower.contains('refers to')) {
        definitions.add(p);
      } else if (lower.contains('example') ||
          lower.contains('for instance') ||
          lower.contains('consider') ||
          lower.contains('suppose') ||
          lower.contains('code:')) {
        examples.add(p);
      } else if (lower.contains('=') ||
          lower.contains('o(') ||
          lower.contains('formula') ||
          lower.contains('equation') ||
          lower.contains('steps:')) {
        formulas.add(p);
      } else {
        keyPoints.add(p);
      }
    }

    final primaryDef = definitions.isNotEmpty
        ? definitions.first
        : paragraphs.first;
    final primaryEx = examples.isNotEmpty
        ? examples.first
        : 'For example, consider how $resolvedTopic processes inputs step-by-step to achieve the desired outcome.';
    final primaryFormula = formulas.isNotEmpty ? formulas.first : '';

    final sections = <LessonSection>[];

    // 1. Introduction & Motivation
    final teluguIntro = '$resolvedTopic అనేది ఒక ముఖ్యమైన concept. $primaryDef. '
        'మనం real-world engineering systems లో efficient గా problems solve చేయడానికి $resolvedTopic ని ఉపయోగిస్తాము.';
    sections.add(_createSection(
      topicId: 0,
      order: 0,
      title: '1. Introduction & Motivation',
      definition: primaryDef,
      importance: 'Fundamental semester exam concept and building block for problem solving.',
      explanation: 'Let us understand the primary motivation behind $resolvedTopic.\n$cleanText',
      example: primaryEx,
      teluguExplanation: teluguIntro,
      examPoints: '• State the foundational definition clearly.\n• Mention why this concept was introduced.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 2. Core Concepts & Definitions
    final teluguDef = '$resolvedTopic working mechanism ని పరిశీలిస్తే: core principles మరియు step-by-step logic ని follow అవ్వడం ముఖ్యం. '
        'ప్రధాన technical terms ని exam లో స్పష్టంగా పేర్కొనాలి.';
    sections.add(_createSection(
      topicId: 0,
      order: 1,
      title: '2. Core Concepts & Definitions',
      definition: primaryDef,
      importance: 'Tested frequently in 5-mark conceptual questions.',
      explanation: 'Let us break down the exact definitions and core mechanics:\n'
          '${keyPoints.isNotEmpty ? keyPoints.take(2).join('\n\n') : primaryDef}',
      example: primaryEx,
      teluguExplanation: teluguDef,
      examPoints: '• Highlight core keywords.\n• Explain the deterministic steps clearly.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 3. Why It Is Needed & Practical Value
    final teluguNeed = '$resolvedTopic ఎందుకు అవసరమంటే: systems లో efficiency పెంచడానికి, complexity తగ్గించడానికి ఇది అత్యంత అవసరం.';
    sections.add(_createSection(
      topicId: 0,
      order: 2,
      title: '3. Why It Is Needed',
      definition: primaryDef,
      importance: 'Helps students frame the "Need and Scope" section in semester exams.',
      explanation: 'Why do we need $resolvedTopic?\n'
          'In engineering design, avoiding redundancy and ensuring optimal performance requires structured methodologies. '
          'Without $resolvedTopic, implementations become fragile and difficult to maintain.',
      example: primaryEx,
      teluguExplanation: teluguNeed,
      examPoints: '• Cite 3 clear engineering advantages.\n• Contrast with naive alternatives.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 4. Main Components & Architecture
    final teluguComponents = '$resolvedTopic లో ప్రధాన components మరియు structural elements ఉంటాయి. ప్రతి component తన నిర్దిష్ట పనిని చేస్తుంది.';
    sections.add(_createSection(
      topicId: 0,
      order: 3,
      title: '4. Main Components & Architecture',
      definition: primaryDef,
      importance: 'Essential for architecture and block diagram questions.',
      explanation: 'Here are the primary components:\n'
          '${primaryFormula.isNotEmpty ? primaryFormula : keyPoints.isNotEmpty ? keyPoints.first : cleanText}',
      example: primaryEx,
      teluguExplanation: teluguComponents,
      examPoints: '• Draw block diagrams neatly.\n• Label all inputs, process modules, and outputs.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 5. Practical Example & Walkthrough
    final teluguExample = 'ఒక practical example ద్వారా చూస్తే: $primaryEx. ఈ concrete scenario ద్వారా concept సులభంగా అర్థమవుతుంది.';
    sections.add(_createSection(
      topicId: 0,
      order: 4,
      title: '5. Practical Example & Walkthrough',
      definition: primaryDef,
      importance: 'Illustrative examples earn top presentation marks in university exams.',
      explanation: 'Now let us observe this through a concrete example:\n$primaryEx\n'
          '${primaryFormula.isNotEmpty ? '\nGoverning Relationship / Formula:\n$primaryFormula' : ''}',
      example: primaryEx,
      teluguExplanation: teluguExample,
      examPoints: '• Always include an example to secure full 5 or 10 marks.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 6. Real-World Applications
    final teluguApps = '$resolvedTopic industrial applications లో విస్తృతంగా ఉపయోగించబడుతుంది. Automation మరియు cloud platforms దీనికి ఉదాహరణలు.';
    sections.add(_createSection(
      topicId: 0,
      order: 5,
      title: '6. Real-World Applications',
      definition: primaryDef,
      importance: 'Provides context for project-oriented and application questions.',
      explanation: 'In the technology industry, $resolvedTopic is utilized across modern software engineering, data pipelines, and scalable architectures.',
      example: 'Applied in high-throughput enterprise systems and cloud services.',
      teluguExplanation: teluguApps,
      examPoints: '• Give 2 real-world domain examples (e.g. Finance, Healthcare, Cloud).',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 7. Common Mistakes & Edge Cases
    final teluguPitfalls = 'Students సాధారణంగా చేసే mistakes: edge cases ను గమనించకపోవడం మరియు theoretical definition ను implementation తో confuse అవ్వడం.';
    sections.add(_createSection(
      topicId: 0,
      order: 6,
      title: '7. Common Mistakes & Edge Cases',
      definition: 'Mistakes students commonly make when answering questions on $resolvedTopic.',
      importance: 'Prevents losing marks on edge cases and false assumptions.',
      explanation: 'Students often confuse theoretical definitions with implementation details. '
          'Be careful not to miss boundary conditions or assume incorrect time/memory bounds.',
      example: 'Assuming best-case behavior applies universally to all inputs.',
      teluguExplanation: teluguPitfalls,
      examPoints: '• Clearly identify edge conditions.\n• Double check worst-case assumptions.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 8. Important Points to Remember
    final teluguImportant = '$resolvedTopic లో గుర్తుంచుకోవలసిన ముఖ్యమైన points: key definitions, syntax rules మరియు constraints.';
    sections.add(_createSection(
      topicId: 0,
      order: 7,
      title: '8. Important Points to Remember',
      definition: primaryDef,
      importance: 'High-speed revision notes for pre-exam review.',
      explanation: 'Key takeaways to retain:\n'
          '1. Foundational principle: $primaryDef\n'
          '2. Practical utility: ${primaryEx.length > 100 ? primaryEx.substring(0, 100) : primaryEx}\n'
          '3. Critical constraint: Ground understanding in original source material.',
      example: primaryEx,
      teluguExplanation: teluguImportant,
      examPoints: '• Memorize core definitions and properties.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 9. Semester Exam High-Yield Points
    final teluguExam = 'Semester exam లో scoring strategy: 2-marks కి concise definition, 5-marks కి neat points + example, 10-marks కి complete trace రాయాలి.';
    sections.add(_createSection(
      topicId: 0,
      order: 8,
      title: '9. Semester Exam High-Yield Points',
      definition: primaryDef,
      importance: '2-Mark, 5-Mark, and 10-Mark exam blueprint.',
      explanation: 'Here is how you should structure your semester exam answer sheet:\n'
          '• 2-Mark Question: State definition in 2 lines and cite 1 key formula/property.\n'
          '• 5-Mark Question: Draw a clean diagram/block, list 4 canonical points, and give a short example.\n'
          '• 10-Mark Question: Complete derivation, tabular comparison, step-by-step trace, and analysis.',
      example: primaryEx,
      teluguExplanation: teluguExam,
      examPoints: '• 2-Mark: Define $resolvedTopic\n• 5-Mark: Explain principles with example\n• 10-Mark: In-depth analysis',
      language: language,
      topicTitle: resolvedTopic,
    ));

    // 10. Quick Revision & Summary
    final teluguSummary = 'మొత్తం summary: $resolvedTopic core definition, ప్రధాన example మరియు key exam points ని revision చేసుకోవడం ముఖ్యం.';
    sections.add(_createSection(
      topicId: 0,
      order: 9,
      title: '10. Quick Revision & Summary',
      definition: primaryDef,
      importance: 'Final wrap-up before attempting the topic quiz.',
      explanation: 'To recap $resolvedTopic:\n'
          '1. Concept: $primaryDef\n'
          '2. Primary Example: $primaryEx\n'
          '3. Core Takeaway: Ground your understanding in foundational principles.',
      example: primaryEx,
      teluguExplanation: teluguSummary,
      examPoints: '• Revise bullet points before entering the exam hall.',
      language: language,
      topicTitle: resolvedTopic,
    ));

    return Topic(
      id: null,
      subjectId: 0,
      title: resolvedTopic,
      summary: primaryDef,
      orderIndex: 0,
      sections: sections,
    );
  }

  LessonSection _createSection({
    required int topicId,
    required int order,
    required String title,
    required String definition,
    required String importance,
    required String explanation,
    required String example,
    required String teluguExplanation,
    required String examPoints,
    required AppLanguage language,
    required String topicTitle,
  }) {
    final script = generateClassroomScript(
      sectionTitle: title,
      explanation: explanation,
      example: example,
      teluguExplanation: teluguExplanation,
      examPoints: examPoints,
      language: language,
      topicTitle: topicTitle,
    );

    return LessonSection(
      topicId: topicId,
      sectionOrder: order,
      title: title,
      definition: definition,
      importance: importance,
      explanation: explanation,
      example: example,
      teluguExplanation: teluguExplanation,
      examPoints: examPoints,
      checkQuestion: 'What is the primary takeaway for $title?',
      checkAnswer: definition,
      classroomScript: script,
    );
  }

  LessonSection _enrichSectionWithClassroomScript(
    LessonSection section,
    AppLanguage language,
    String topicTitle,
  ) {
    if (section.classroomScript != null && section.classroomScript!.isNotEmpty) {
      return section;
    }

    final script = generateClassroomScript(
      sectionTitle: section.title,
      explanation: section.explanation,
      example: section.example,
      teluguExplanation: section.teluguExplanation,
      examPoints: section.examPoints,
      language: language,
      topicTitle: topicTitle,
    );

    return section.copyWith(classroomScript: script);
  }

  /// Generates a natural, human-like classroom speech script for teacher delivery.
  /// Supports English, Telugu, and Telugu + English with proper Telugu script.
  static String generateClassroomScript({
    required String sectionTitle,
    required String explanation,
    required String example,
    required String teluguExplanation,
    required String examPoints,
    required AppLanguage language,
    required String topicTitle,
  }) {
    switch (language) {
      case AppLanguage.english:
        final buffer = StringBuffer();
        buffer.write('Okay class, let us focus on $sectionTitle. ');
        buffer.write('$explanation ');
        if (example.isNotEmpty) {
          buffer.write('To make this concrete, let us look at an example: $example. ');
        }
        if (examPoints.isNotEmpty) {
          buffer.write('Now, here is an important tip for your semester exam: $examPoints ');
        }
        buffer.write('Make sure you note this down.');
        return buffer.toString();

      case AppLanguage.telugu:
        final buffer = StringBuffer();
        buffer.write('సరే students, ఇప్పుడు మనం $sectionTitle గురించి నేర్చుకుందాం. ');
        buffer.write(teluguExplanation.isNotEmpty ? '$teluguExplanation ' : '$explanation ');
        if (example.isNotEmpty) {
          buffer.write('ఒక practical example చూస్తే: $example. ');
        }
        if (examPoints.isNotEmpty) {
          buffer.write('Exam point of view లో ఇది చాలా ముఖ్యమైనది: $examPoints ');
        }
        buffer.write('దీని మీద మీకు ఏదైనా doubt ఉంటే అడగవచ్చు.');
        return buffer.toString();

      case AppLanguage.teluguEnglish:
        final buffer = StringBuffer();
        buffer.write('Okay, ippudu manam $sectionTitle chuddam. ');
        if (teluguExplanation.isNotEmpty) {
          buffer.write('$teluguExplanation ');
        } else {
          buffer.write('Simple ga cheppalante, $explanation ');
        }
        if (example.isNotEmpty) {
          buffer.write('Example chuddam: $example. ');
        }
        if (examPoints.isNotEmpty) {
          buffer.write('Exam point of view lo idi chala important: $examPoints ');
        }
        buffer.write('Meeku ikkada emaina doubt unte feel free ga adagandi.');
        return buffer.toString();
    }
  }

  /// Mode C: Teach My Notes Line-by-Line
  /// The student's pasted content is the PRIMARY SOURCE and is taught
  /// in the EXACT sequential order of the original notes without reordering.
  Topic buildLineByLineLesson({
    String? topicTitle,
    required String content,
    required AppLanguage language,
  }) {
    final cleanText = content.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Study content cannot be empty.');
    }

    final resolvedTopic = (topicTitle != null && topicTitle.trim().isNotEmpty)
        ? topicTitle.trim()
        : inferTopicTitle(cleanText);

    // Split into paragraphs preserving raw formatting
    final rawParagraphs = cleanText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Flatten paragraphs into logical sentences/lines
    final segmentsList = <TeachingSegment>[];
    final sections = <LessonSection>[];

    int globalIndex = 0;

    for (int pIdx = 0; pIdx < rawParagraphs.length; pIdx++) {
      final pText = rawParagraphs[pIdx];

      // If paragraph has single newline-separated lines, respect line structure
      List<String> lines;
      if (pText.contains('\n')) {
        lines = pText
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
      } else {
        // Otherwise split by sentence boundaries
        lines = splitIntoSpeechSegments(pText);
      }

      for (int lIdx = 0; lIdx < lines.length; lIdx++) {
        final line = lines[lIdx];
        if (line.isEmpty) continue;

        final prevLine = globalIndex > 0 && segmentsList.isNotEmpty ? segmentsList.last.originalText : null;
        final explanation = generateLineExplanation(
          line: line,
          topic: resolvedTopic,
          language: language,
          index: globalIndex,
          prevLine: prevLine,
        );

        final speechText = TtsService.toSpeechFriendlyText(explanation);
        final segmentId = 'seg_${pIdx}_$lIdx';

        final segment = TeachingSegment(
          segmentId: segmentId,
          originalText: line,
          teacherExplanation: explanation,
          speechText: speechText,
          sectionIndex: globalIndex,
          paragraphIndex: pIdx,
          lineIndex: lIdx,
        );

        segmentsList.add(segment);

        // Section title format
        final shortTitle = line.length > 45 ? '${line.substring(0, 45)}...' : line;

        sections.add(
          LessonSection(
            topicId: 0,
            title: 'Line ${globalIndex + 1}: $shortTitle',
            definition: line,
            importance: 'Part of your study material ($resolvedTopic).',
            explanation: explanation,
            example: '',
            teluguExplanation: language == AppLanguage.teluguEnglish ? explanation : '',
            examPoints: 'Remember this exact point from your notes.',
            checkQuestion: 'What does this line explain about $resolvedTopic?',
            checkAnswer: line,
            sectionOrder: globalIndex,
            classroomScript: speechText,
            originalText: line,
            segment: segment,
          ),
        );

        globalIndex++;
      }
    }

    if (sections.isEmpty) {
      sections.add(
        LessonSection(
          topicId: 0,
          title: 'Section 1',
          definition: cleanText,
          explanation: cleanText,
          sectionOrder: 0,
          originalText: cleanText,
        ),
      );
    }

    return Topic(
      id: 0,
      subjectId: 0,
      title: resolvedTopic,
      summary: 'Line-by-Line Teaching of Student Notes',
      orderIndex: 0,
      sections: sections,
    );
  }

  /// Generates a human-like classroom explanation for a specific line of student notes.
  static String generateLineExplanation({
    required String line,
    required String topic,
    required AppLanguage language,
    int index = 0,
    String? prevLine,
  }) {
    final cleanLine = line.trim();
    final lower = cleanLine.toLowerCase();

    switch (language) {
      case AppLanguage.english:
        final buffer = StringBuffer();
        if (cleanLine.contains(RegExp(r'\bstands for\b', caseSensitive: false))) {
          buffer.write('Here, your notes state: "$cleanLine". In simple terms, this defines what the acronym means. ');
        } else if (cleanLine.contains(RegExp(r'\ballows|enables|helps\b', caseSensitive: false))) {
          buffer.write('This line explains the core purpose: "$cleanLine". Simply put, it connects different components so they work together seamlessly. ');
        } else if (cleanLine.contains(RegExp(r'\brequest\b', caseSensitive: false))) {
          buffer.write('Looking at this step: "$cleanLine". In computing, a client asks the server for resources or data. ');
        } else if (cleanLine.contains(RegExp(r'\bprocesses|response\b', caseSensitive: false))) {
          buffer.write('Next step in your notes: "$cleanLine". The server computes the result and sends the data back to the caller. ');
        } else {
          buffer.write('In this line, your notes explain: "$cleanLine". To understand this clearly, focus on the fundamental definition and how it connects to $topic. ');
        }
        buffer.write('Let us understand this carefully before moving forward.');
        return buffer.toString();

      case AppLanguage.telugu:
        final buffer = StringBuffer();
        buffer.write('ఈ line లో మీ notes లో: "$cleanLine" అని ఉంది. ');
        buffer.write('దీనిని simple గా అర్థం చేసుకోవాలంటే: ఈ concept $topic లో ముఖ్యమైన step. ');
        buffer.write('దీని మీద మీకు ఏదైనా doubt ఉంటే అడగండి.');
        return buffer.toString();

      case AppLanguage.teluguEnglish:
        // Indian college teacher Tanglish
        final buffer = StringBuffer();

        // 1. Acronym / "stands for"
        final standsForMatch = RegExp(r'([A-Za-z0-9_\-\s]+)\s+stands\s+for\s+([^\.]+)', caseSensitive: false).firstMatch(cleanLine);
        if (standsForMatch != null) {
          final acronym = standsForMatch.group(1)?.trim() ?? 'Idi';
          final expansion = standsForMatch.group(2)?.trim() ?? '';
          buffer.write('$acronym ante $expansion. ');
          buffer.write('Simple ga cheppalante, different software applications madhyalo communication jaragadaniki use chese interface ni $acronym ani antaru.');
          return buffer.toString();
        }

        // 2. Communication between applications
        if (lower.contains('communicat') && lower.contains('application')) {
          buffer.write('Simple ga cheppalante, rendu applications madhyalo communication jaragadaniki API help chestundi.');
          return buffer.toString();
        }

        // 3. Client sends request
        if (lower.contains('client') && (lower.contains('request') || lower.contains('send'))) {
          buffer.write('Client ante mana browser leda mobile application. Idi server ki data kavali ani request ni send chestundi.');
          return buffer.toString();
        }

        // 4. Server processes request & sends response
        if (lower.contains('server') && (lower.contains('process') || lower.contains('response'))) {
          buffer.write('Server aa request ni process chesi, kavalsina data ni response roopam lo client ki back send chestundi.');
          return buffer.toString();
        }

        // 5. Variables
        if (lower.contains('variable') && (lower.contains('store') || lower.contains('memory') || lower.contains('name'))) {
          buffer.write('Variable ante data ni store cheyyadaniki use chese oka named location. Programming lo idi values ni save cheskuntundi.');
          return buffer.toString();
        }

        // 6. Functions
        if (lower.contains('function') && (lower.contains('block') || lower.contains('task') || lower.contains('reusable'))) {
          buffer.write('Function ante oka specific task ni perform cheyadaniki use chese reusable block of code.');
          return buffer.toString();
        }

        // 7. Recursion
        if (lower.contains('recursion') || lower.contains('calls itself')) {
          buffer.write('Recursion ante oka function thanani thane call chesukovadam. Simple ga cheppalante, problem ni smaller subproblems ga divide chesi solve cheyyadam.');
          return buffer.toString();
        }

        // Heuristic fallback for any custom sentence
        buffer.write('Ikkada mee notes lo line: "$cleanLine". ');
        buffer.write('Simple ga cheppalante, idi $topic lo oka important concept. ');
        buffer.write('Meeku ikkada emaina doubt unte feel free ga adagandi.');
        return buffer.toString();
    }
  }
}
