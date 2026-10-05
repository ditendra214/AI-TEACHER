import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/teaching_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(TeachingState state) {
    final query = _textController.text.trim();
    if (query.isNotEmpty) {
      _textController.clear();
      state.askQuestion(query);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);
    final messages = state.messages;
    final isGenerating = state.isGenerating;
    final streamingBuffer = state.streamingBuffer;
    final isDoubt = state.isInDoubtInterruption;

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              isDoubt ? 'Doubt Mode' : 'AI Exam Tutor',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (state.interruptedSectionTitle != null && isDoubt)
              Text(
                'Lesson: ${state.interruptedSectionTitle}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Return to Lesson Button (Doubt Interruption System)
          if (isDoubt)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await state.returnToLesson();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Return to Lesson', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') state.clearCurrentChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat History')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Doubt Interruption Banner
          if (isDoubt)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline, color: Colors.amber.shade900, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lesson paused at "${state.interruptedSectionTitle}". Ask doubts freely.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Message Bubbles List
          Expanded(
            child: messages.isEmpty && streamingBuffer.isEmpty
                ? _buildEmptyState(state)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length + (streamingBuffer.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < messages.length) {
                        return _buildMessageBubble(context, messages[index]);
                      } else {
                        return _buildStreamingBubble(context, streamingBuffer);
                      }
                    },
                  ),
          ),

          // Generating / Thinking Indicator with Stop Button
          if (isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('AI Teacher is thinking...', style: TextStyle(fontSize: 12, color: Colors.blue)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => state.stopGeneration(),
                    child: const Text('Stop Generation', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(state),
                      decoration: InputDecoration(
                        hintText: isDoubt
                            ? 'Ask doubt about this concept...'
                            : 'Ask any exam question or doubt...',
                        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: isGenerating ? null : () => _sendMessage(state),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TeachingState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 56, color: Colors.blue.shade300),
            const SizedBox(height: 16),
            const Text(
              'Personal Exam Doubt Tutor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask any concept question, request Telugu+English intuition, or paste an exam question.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('What is Big O notation?', state),
                _suggestionChip('Explain Divide & Conquer with an example', state),
                _suggestionChip('Telugu lo explain cheyandi', state),
                _suggestionChip('Important 2-mark questions for this topic', state),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text, TeachingState state) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade100),
      onPressed: () {
        _textController.text = text;
        _sendMessage(state);
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final isUser = message.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser ? const Color(0xFF1D4ED8) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (message.contextTag != null && message.isDoubt && !isUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                'Context: ${message.contextTag}',
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser ? null : Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SelectableText(
              message.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: textColor,
              ),
            ),
          ),
          if (!isUser) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 15, color: Colors.grey),
                  tooltip: 'Copy Answer',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              text.isEmpty ? 'Typing...' : text,
              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
