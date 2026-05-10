import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/theme.dart';
import '../services/ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AiHomeScreen extends StatefulWidget {
  const AiHomeScreen({super.key});

  @override
  State<AiHomeScreen> createState() => _AiHomeScreenState();
}

class _AiHomeScreenState extends State<AiHomeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  int _activeBuses = 0;
  int _activeAlerts = 0;
  Map<String, dynamic>? _latestBus;
  Map<String, dynamic>? _latestRoute;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;

  final List<String> _suggestions = [
    'How many buses are active now?',
    'Are there any emergencies?',
    'What is SafeTrack?',
    'How does the safety system work?',
    'What sensors are used in buses?',
    'How do I track a bus?',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _initTts();
    _messages.add({
      'role': 'assistant',
      'text':
          '👋 Hello! I\'m SafeTrack AI, powered by Gemini.\n\nI can help you with bus safety information, how to track buses, understand alerts, and more. What would you like to know?',
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");

    await _tts.setSpeechRate(0.45);

    await _tts.setPitch(1.0);
    _tts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  Future<void> _loadStats() async {
    try {
      final buses = await FirebaseFirestore.instance
          .collection('buses')
          .where('isActive', isEqualTo: true)
          .get();
      final alerts = await FirebaseFirestore.instance
          .collection('alerts')
          .where('isResolved', isEqualTo: false)
          .get();
      final latestBus =
          await FirebaseFirestore.instance.collection('buses').limit(1).get();
      final latestRoute =
          await FirebaseFirestore.instance.collection('routes').limit(1).get();
      if (mounted) {
        setState(() {
          _activeBuses = buses.docs.length;
          _activeAlerts = alerts.docs.length;

          _latestBus =
              latestBus.docs.isNotEmpty ? latestBus.docs.first.data() : null;
          _latestRoute = latestRoute.docs.isNotEmpty
              ? latestRoute.docs.first.data()
              : null;
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic> _buildContext() => {
        'activeBuses': _activeBuses,
        'activeAlerts': _activeAlerts,
        'appName': 'SafeTrack',
        'busName': _latestBus?['busName'] ?? '',
        'busNumber': _latestBus?['busNumber'] ?? '',
        'status': _latestBus?['status'] ?? '',
        'safetyStatus': _latestBus?['safetyStatus'] ?? '',
        'availableSeats': _latestBus?['availableSeats'] ?? '',
        'seatCapacity': _latestBus?['seatCapacity'] ?? '',
        'source': _latestRoute?['source'] ?? '',
        'destination': _latestRoute?['destination'] ?? '',
        'arrivalTime': _latestRoute?['arrivalTime'] ?? '',
        'departureTime': _latestRoute?['departureTime'] ?? '',
        'serviceNumber': _latestRoute?['serviceNumber'] ?? '',
      };

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Build history excluding the first assistant greeting
      final history = _messages
          .where((m) => _messages.indexOf(m) > 0)
          .map((m) => {'role': m['role']!, 'content': m['text']!})
          .toList();

      final reply = await AiService.chat(
        userMessage: text,
        history: history,
        busContext: _buildContext(),
      );

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': reply,
          });

          _loading = false;
        });

        await _tts.speak(reply);
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': 'Sorry, I couldn\'t connect right now. Please try again.',
          });
          _loading = false;
        });
      }
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();

    if (available) {
      setState(() {
        _isListening = true;
      });

      Future<void> _startListening() async {
        bool available = await _speech.initialize();

        if (available) {
          setState(() {
            _isListening = true;
          });

          _speech.listen(
            listenFor: const Duration(seconds: 15),
            pauseFor: const Duration(seconds: 2),
            onResult: (result) async {
              setState(() {
                _controller.text = result.recognizedWords;
              });

              if (result.finalResult) {
                final text = result.recognizedWords.trim();

                await _stopListening();

                if (text.isNotEmpty) {
                  _sendMessage(text);
                }
              }
            },
          );
        }
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _speakMessage(String text) async {
    if (_isSpeaking) {
      await _tts.stop();

      setState(() {
        _isSpeaking = false;
      });

      return;
    }

    await _tts.speak(text);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
          ),
        ),
        title: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SafeTrack AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
            child: Row(
              children: [
                _statChip(
                    '🚌 $_activeBuses Active Buses', const Color(0xFF6366F1)),
                const SizedBox(width: 10),
                _statChip(
                  '⚠ $_activeAlerts Alerts',
                  _activeAlerts > 0 ? AppTheme.dangerColor : AppTheme.safeColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessage(msg['text']!, msg['role'] == 'user');
              },
            ),
          ),
          if (_messages.length <= 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_suggestions[i],
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _sendMessage(_suggestions[i]),
                  backgroundColor:
                      const Color(0xFF6366F1).withValues(alpha: 0.08),
                  side: BorderSide(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask anything about SafeTrack...',
                      hintStyle: const TextStyle(color: AppTheme.textLight),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isListening
                        ? const _VoiceWave()
                        : const Icon(
                            Icons.mic_none,
                            color: Colors.black87,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMessage(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                )
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _speakMessage(text),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                      size: 18,
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSpeaking ? 'Stop' : 'Listen',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => _AnimatedDot(delay: i * 200),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0).animate(_c);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: Color(0xFF6366F1),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _VoiceWave extends StatefulWidget {
  const _VoiceWave();

  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave> with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  void initState() {
    super.initState();

    _c1 = _buildController(0);
    _c2 = _buildController(150);
    _c3 = _buildController(300);
  }

  AnimationController _buildController(int delay) {
    final c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.3,
      upperBound: 1.0,
    );

    Future.delayed(
      Duration(milliseconds: delay),
      () {
        if (mounted) {
          c.repeat(reverse: true);
        }
      },
    );

    return c;
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  Widget _bar(AnimationController c) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        return Container(
          width: 4,
          height: 18 * c.value,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(_c1),
        _bar(_c2),
        _bar(_c3),
      ],
    );
  }
}
