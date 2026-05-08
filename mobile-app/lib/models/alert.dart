import 'package:cloud_firestore/cloud_firestore.dart';

class BusAlert {
  final String id;
  final String busNumber;
  final String alertType;
  final String severity;
  final String message;
  final double latitude;
  final double longitude;
  final bool isResolved;
  final String? timestamp;

  BusAlert({
    required this.id,
    required this.busNumber,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.isResolved,
    this.timestamp,
  });

  factory BusAlert.fromJson(Map<String, dynamic> json) {
    // convert Firestore Timestamp to ISO string
    String? ts;
    if (json['timestamp'] is Timestamp) {
      ts = (json['timestamp'] as Timestamp).toDate().toIso8601String();
    } else if (json['timestamp'] is String) {
      ts = json['timestamp'];
    }

    return BusAlert(
      id: json['id'] ?? '',
      busNumber: json['busNumber'] ?? '',
      alertType: json['alertType'] ?? '',
      severity: json['severity'] ?? '',
      message: json['message'] ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isResolved: json['isResolved'] ?? false,
      timestamp: ts,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
