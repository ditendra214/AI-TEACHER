import 'package:flutter/material.dart';
import '../data/models/document_model.dart';
import '../data/models/subject_model.dart';
import '../features/splash/splash_screen.dart';
import '../features/model_setup/model_setup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/subjects/subjects_screen.dart';
import '../features/subjects/topic_list_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/documents/document_details_screen.dart';
import '../features/teacher/teacher_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/exam/exam_prep_screen.dart';
import '../features/revision/revision_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/diagnostics_screen.dart';
import '../features/home/help_screen.dart';
import '../features/classroom/classroom_screen.dart';
import '../features/classroom/teach_material_screen.dart';

class AppRoutes {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/classroom':
        return MaterialPageRoute(builder: (_) => const ClassroomScreen());
      case '/teach_material':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => TeachMaterialScreen(
            initialTopic: args?['topic'] as String?,
            initialContent: args?['content'] as String?,
          ),
        );
      case '/model_setup':
        return MaterialPageRoute(builder: (_) => const ModelSetupScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/subjects':
        return MaterialPageRoute(builder: (_) => const SubjectsScreen());
      case '/topic_list':
        final args = settings.arguments as Map<String, dynamic>?;
        final subject = args?['subject'] as Subject;
        return MaterialPageRoute(builder: (_) => TopicListScreen(subject: subject));
      case '/documents':
        return MaterialPageRoute(builder: (_) => const DocumentsScreen());
      case '/document_details':
        final args = settings.arguments as Map<String, dynamic>?;
        final doc = args?['document'] as DocumentModel;
        return MaterialPageRoute(builder: (_) => DocumentDetailsScreen(document: doc));
      case '/teacher':
        return MaterialPageRoute(builder: (_) => const TeacherScreen());
      case '/chat':
        return MaterialPageRoute(builder: (_) => const ChatScreen());
      case '/quiz':
        final args = settings.arguments as Map<String, dynamic>?;
        final topicId = args?['topicId'] as int?;
        final topicTitle = args?['topicTitle'] as String?;
        return MaterialPageRoute(
          builder: (_) => QuizScreen(topicId: topicId, topicTitle: topicTitle),
        );
      case '/exam_prep':
        return MaterialPageRoute(builder: (_) => const ExamPrepScreen());
      case '/revision':
        return MaterialPageRoute(builder: (_) => const RevisionScreen());
      case '/progress':
        return MaterialPageRoute(builder: (_) => const ProgressScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/diagnostics':
        return MaterialPageRoute(builder: (_) => const DiagnosticsScreen());
      case '/help':
        return MaterialPageRoute(builder: (_) => const HelpScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
