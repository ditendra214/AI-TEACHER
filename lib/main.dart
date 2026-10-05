import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme.dart';
import 'app/routes.dart';
import 'core/constants/app_constants.dart';
import 'data/database/db_helper.dart';
import 'data/repositories/app_repository.dart';
import 'data/services/model_manager.dart';
import 'data/services/teaching_state.dart';
import 'ai/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database (seeds Algorithms course automatically)
  await DbHelper.database;

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize AI service
  final aiService = AiService();

  // Initialize Repository
  final repository = AppRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppRepository>.value(value: repository),
        ChangeNotifierProvider<ModelManager>(
          create: (_) => ModelManager(prefs: prefs, aiService: aiService),
        ),
        ChangeNotifierProvider<TeachingState>(
          create: (_) => TeachingState(
            repository: repository,
            aiService: aiService,
            prefs: prefs,
          ),
        ),
      ],
      child: const AiTeacherApp(),
    ),
  );
}

class AiTeacherApp extends StatelessWidget {
  const AiTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} – ${AppConstants.appTagline}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
