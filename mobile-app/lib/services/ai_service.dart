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
    String risk = 'LOW';

    String prediction = 'Bus is operating normally.';

    String action = 'No immediate danger detected.';

    // CRITICAL
    if (temperature > 70 || flameDetected) {
      risk = 'CRITICAL';

      prediction = 'Fire hazard detected inside bus.';

      action = 'Stop the bus immediately.';
    }

    // HIGH
    else if (smokeDetected || tiltAngle > 30) {
      risk = 'HIGH';

      prediction = 'Possible accident or smoke detected.';

      action = 'Inspect the bus immediately.';
    }

    // MEDIUM
    else if (speed > 80) {
      risk = 'MEDIUM';

      prediction = 'Bus speed is high.';

      action = 'Drive carefully.';
    }

    // LOW
    else {
      risk = 'LOW';

      prediction = 'Bus is currently safe.';

      action = 'No immediate action required.';
    }

    return PredictiveResult(
      riskLevel: risk,
      prediction: prediction,
      action: action,
    );
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
- Departure: ${busContext['departureTime']}
- Arrival: ${busContext['arrivalTime']}
- Service Number: ${busContext['serviceNumber']}
- Stops: ${busContext['intermediateStops']}
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
      final callable = _functions.httpsCallable('askAI');

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
      print('Firebase Groq API with LLaMA 3 Error: $e');

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
