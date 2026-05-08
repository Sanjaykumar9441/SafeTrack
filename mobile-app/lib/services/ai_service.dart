import 'dart:ui';
import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static Future<PredictiveResult> predictRisk({
    required double temperature,
    required bool flameDetected,
    required bool smokeDetected,
    required double tiltAngle,
    required double speed,
    required String busNumber,
  }) async {
    try {
      final callable = _functions.httpsCallable('askGemini');

      final prompt = '''
You are a bus safety AI for SafeTrack.

Analyze these live bus conditions:

Bus Number: $busNumber
Temperature: $temperature °C
Flame Detected: $flameDetected
Smoke Detected: $smokeDetected
Tilt Angle: $tiltAngle °
Speed: $speed km/h

Return ONLY one word:
LOW
MEDIUM
HIGH
CRITICAL
''';

      final response = await callable.call({
        'prompt': prompt,
      });

      final data = Map<String, dynamic>.from(response.data);

      final result = (data['text'] ?? 'LOW').toString().trim().toUpperCase();

      return PredictiveResult(
        riskLevel: result,
        prediction: 'AI analyzed current bus conditions.',
        action: result == 'CRITICAL'
            ? 'Stop the bus immediately.'
            : result == 'HIGH'
                ? 'Monitor the bus carefully.'
                : 'No immediate danger detected.',
      );
    } catch (e) {
      print('Predict Risk Error: $e');

      return PredictiveResult(
        riskLevel: 'LOW',
        prediction: 'Unable to analyze at this time.',
        action: 'Monitor sensors manually.',
      );
    }
  }

  static Future<String> chat({
    required String userMessage,
    required List<Map<String, String>> history,
    Map<String, dynamic>? busContext,
  }) async {
    // System context
    String context = '''
You are SafeTrack AI Assistant — a helpful assistant for a smart bus tracking 
and safety system in India.

You help passengers with:
- Bus safety information
- Bus tracking
- Emergency guidance
- Route information
- Sensor explanations
- Travel advice

Keep responses concise, practical, and friendly.
Use simple English.
''';

    // Add live bus context if available
    if (busContext != null) {
      context += '''

Current Bus Context:
- Bus: ${busContext['busName']} (${busContext['busNumber']})
- Status: ${busContext['status']}
- Safety: ${busContext['safetyStatus']}
- Route: ${busContext['source']} → ${busContext['destination']}
- Seats Available: ${busContext['availableSeats']} of ${busContext['seatCapacity']}
- Temperature: ${busContext['temperature']}°C
''';
    }

    // Final AI prompt
    final finalPrompt = '''
$context

Conversation History:
$history

User Message:
$userMessage
''';

    try {
      final callable = _functions.httpsCallable('askGemini');

      final response = await callable.call({
        'prompt': finalPrompt,
      });

      final data = Map<String, dynamic>.from(response.data);

      final text = data['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }

      return 'No response from AI.';
    } catch (e) {
      print('Firebase Gemini Error: $e');

      return 'Connection error. Please try again.';
    }
  }
}

class PredictiveResult {
  final String riskLevel;
  final String prediction;
  final String action;

  PredictiveResult({
    required this.riskLevel,
    required this.prediction,
    required this.action,
  });

  Color get color {
    switch (riskLevel) {
      case 'CRITICAL':
        return const Color(0xFFEF4444);

      case 'HIGH':
        return const Color(0xFFF59E0B);

      case 'MEDIUM':
        return const Color(0xFF3B82F6);

      default:
        return const Color(0xFF10B981);
    }
  }
}
