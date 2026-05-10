import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiSafetyChatScreen extends StatefulWidget {
  final Map<String, dynamic>? busContext;

  const AiSafetyChatScreen({super.key, this.busContext});

  @override
  State<AiSafetyChatScreen> createState() => _AiSafetyChatScreenState();
}

class _AiSafetyChatScreenState extends State<AiSafetyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  bool _loading = false;
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;

  // Quick question chips
  final List<String> _quickQuestions = [
    'Is this bus safe right now?',
    'What does smoke alert mean?',
    'What should I do in emergency?',
    'Explain the safety sensors',
    'What is normal temperature?',
  ];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(_ChatMessage(
      text: widget.busContext != null
          ? 'Hello! I\'m your SafeTrack AI Assistant. I can see you\'re viewing bus ${widget.busContext!['busNumber']}. How can I help you?'
          : 'Hello! I\'m your SafeTrack AI Assistant. Ask me anything about bus safety, routes, or alerts.',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _loading) return;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    // Add to history for multi-turn context
    _history.add({'role': 'user', 'content': text});

    final response = await AiService.chat(
      userMessage: text,
      history: List.from(_history)..removeLast(), // history before this msg
      busContext: widget.busContext,
    );

    _history.add({'role': 'model', 'content': response});

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();

      setState(() {
        _isListening = false;
      });

      return;
    }

    bool available = await _speech.initialize();

    if (!available) return;

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });

        // AUTO SEND
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();

          setState(() {
            _isListening = false;
          });

          _sendMessage(
            result.recognizedWords,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppTheme.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SafeTrack AI',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Powered by AI Assistant',
                    style:
                        TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        // Bus context chip if opened from bus detail
        actions: [
          if (widget.busContext != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(
                  widget.busContext!['busNumber'] ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickQuestions.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_quickQuestions[i],
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => _sendMessage(_quickQuestions[i]),
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                    side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _sendMessage,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask about bus safety...',
                      hintStyle: const TextStyle(color: AppTheme.textLight),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red : Colors.orange,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _loading
                              ? Colors.grey[300]
                              : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _loading ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppTheme.primaryColor, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppTheme.primaryColor, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
              ],
            ),
            child: Row(
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, value, __) => Opacity(
        opacity: value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}
