import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Help / How to Use'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStepCard(
            stepNumber: 1,
            title: 'OPEN THE APP',
            content: 'Open: AI Teacher – Personal Exam Tutor.\nYou will see the Home screen with Subjects, Teach a Topic, and Teach My Material.',
            icon: Icons.home_outlined,
          ),
          _buildStepCard(
            stepNumber: 2,
            title: 'SELECT TEACHING LANGUAGE',
            content: 'Choose from the top-right language selector:\n• English\n• Telugu\n• Telugu + English (Recommended)\n\nFor example, selecting "Telugu + English" causes the teacher to explain naturally in conversational Telugu while keeping technical terms in English.',
            icon: Icons.translate,
          ),
          _buildStepCard(
            stepNumber: 3,
            title: 'LEARN USING ONLY A TOPIC NAME',
            content: 'From Home select: "Teach a Topic".\nEnter: Python (or any computer science subject).\nPress: "Start Teaching".\n\nThe teacher prepares the lesson. You can see the explanation and hear the teacher speak aloud.',
            icon: Icons.topic_outlined,
          ),
          _buildStepCard(
            stepNumber: 4,
            title: 'TEACH FROM YOUR OWN NOTES',
            content: 'Select: "Teach My Material".\nPaste your study material into the large text area.\n\nTopic name is OPTIONAL. You may enter a topic title, or leave it empty — the app will automatically detect the topic from your text!\nPress: "Start Teaching".',
            icon: Icons.note_alt_outlined,
          ),
          _buildStepCard(
            stepNumber: 5,
            title: 'VIEW THE LESSON',
            content: 'The screen shows:\n• Teacher Explanation (with active sentence highlighting)\n• Core Concept & Definition\n• Practical Example\n• Common Pitfalls & Traps\n• Semester Exam High-Yield Points\n• Quick Revision & Summary\n\nHigh contrast layout ensures easy reading in all lighting conditions.',
            icon: Icons.menu_book_outlined,
          ),
          _buildStepCard(
            stepNumber: 6,
            title: 'LISTEN TO THE TEACHER',
            content: 'When speaking is available, the banner displays:\n🔊 Teacher is speaking...\n\nYou can use the bottom controls:\n• ⏸ Pause: stops speech without leaving lesson\n• ▶ Resume: continues speech from exact sentence\n• ⏹ Stop: stops active speech\n\nIf there is no sound, go to: Settings → Diagnostics → Test Voice.',
            icon: Icons.record_voice_over_outlined,
          ),
          _buildStepCard(
            stepNumber: 7,
            title: 'USE BLUETOOTH EARBUDS',
            content: '1. Connect Bluetooth earbuds to your phone.\n2. Turn up media volume.\n3. Open AI Teacher and start a lesson.\n4. Press Speak if needed.\n\nVoice routes automatically through the earbuds using Android Media AudioAttributes. If not heard, check Settings → Diagnostics → Test Voice.',
            icon: Icons.headphones_outlined,
          ),
          _buildStepCard(
            stepNumber: 8,
            title: 'ASK A DOUBT',
            content: 'While the teacher is teaching, press the prominent red button:\n"Ask Doubt"\n\nThe teacher immediately stops speaking and saves your exact position. You can type your doubt or tap the microphone to speak.',
            icon: Icons.help_outline,
          ),
          _buildStepCard(
            stepNumber: 9,
            title: 'SPEAK YOUR DOUBT',
            content: 'Tap the microphone icon.\nWait for the banner: 🔴 Listening...\nSpeak clearly, e.g.: "What is a parameter?"\n\nThe app converts your speech into text and submits it to the tutor.',
            icon: Icons.mic_none,
          ),
          _buildStepCard(
            stepNumber: 10,
            title: 'TEACHER ANSWERS',
            content: 'The teacher grounds the answer in your current topic, section, and study material.\nFor Telugu + English, the answer is displayed and spoken aloud in natural bilingual voice.',
            icon: Icons.chat_bubble_outline,
          ),
          _buildStepCard(
            stepNumber: 11,
            title: 'CONTINUE THE LESSON',
            content: 'After reviewing the answer, press:\n"Continue Lesson"\n\nThe teacher returns to the classroom and continues from where it stopped. It will NOT restart the section or topic.',
            icon: Icons.play_arrow_outlined,
          ),
          _buildStepCard(
            stepNumber: 12,
            title: 'ASK MULTIPLE DOUBTS',
            content: 'You can repeat:\nTeach → Ask Doubt → Answer → Continue Lesson\nas many times as needed during a lecture. All interruptions preserve your exact position.',
            icon: Icons.repeat,
          ),
          _buildStepCard(
            stepNumber: 13,
            title: 'LOCAL AI MODEL (OPTIONAL)',
            content: 'For advanced arbitrary topic teaching:\nSettings → AI & Voice Models → Local AI.\n\nImport a supported GGUF model (e.g. Qwen 2.5 1.5B or 3B). GGUF is completely OPTIONAL. Pre-seeded lessons and pasted material work 100% offline without any model!',
            icon: Icons.memory,
          ),
          _buildStepCard(
            stepNumber: 14,
            title: 'SPEECH RECOGNITION MODEL',
            content: 'For offline voice recognition, Android SpeechRecognizer is used. If offline speech pack is missing, you can always type your doubts. The app never crashes.',
            icon: Icons.keyboard_voice_outlined,
          ),
          _buildStepCard(
            stepNumber: 15,
            title: 'CHECK VOICE',
            content: 'Go to Settings → Diagnostics → Test Voice.\nYour phone will say: "Hello. This is your AI Teacher voice test." and test both English and Telugu voices.',
            icon: Icons.hearing_outlined,
          ),
          _buildStepCard(
            stepNumber: 16,
            title: 'CHECK MICROPHONE',
            content: 'Go to Settings → Diagnostics → Test Microphone.\nPress Start Test and say: "Hello teacher."\nThe recognized words will appear on screen.',
            icon: Icons.mic,
          ),
          _buildStepCard(
            stepNumber: 17,
            title: 'IF MICROPHONE PERMISSION IS DENIED',
            content: 'Go to Android Settings → Apps → AI Teacher → Permissions → Microphone → Allow. Then return to the app.',
            icon: Icons.security,
          ),
          _buildStepCard(
            stepNumber: 18,
            title: 'IF TELUGU VOICE IS NOT AVAILABLE',
            content: 'Go to Android Settings → Accessibility / System → Text-to-Speech Output. Ensure Google Text-to-Speech is selected and download Telugu (India) voice data.',
            icon: Icons.settings_suggest_outlined,
          ),
          _buildStepCard(
            stepNumber: 19,
            title: 'OFFLINE USE',
            content: 'With local content and Android TTS, the application works 100% offline without internet. Cloud AI is strictly optional.',
            icon: Icons.wifi_off,
          ),
          _buildStepCard(
            stepNumber: 20,
            title: 'IMPORTANT DISTINCTION',
            content: 'Remember that three separate systems work together:\n1. Text-to-Speech: Teacher text → Spoken voice\n2. Speech-to-Text: Student voice → Doubt text\n3. Local AI: Material/topic → Explanations & answers\n\nInstalling one does not automatically install the others.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'AI Teacher User Guide',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Your personal exam tutor for semester preparation, study material teaching, and spoken doubt clearing.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF1D4ED8).withAlpha(25),
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: Colors.grey.shade600),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
