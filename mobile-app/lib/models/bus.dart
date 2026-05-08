class Bus {
  final String id;
  final String busNumber;
  final String busName;
  final int seatCapacity;
  final int availableSeats;
  final String status;
  final String safetyStatus;
  final bool isActive;
  final double currentLatitude;
  final double currentLongitude;
  final double temperature;
  final String? deviceId;

  Bus({
    required this.id,
    required this.busNumber,
    required this.busName,
    required this.seatCapacity,
    required this.availableSeats,
    required this.status,
    required this.safetyStatus,
    required this.isActive,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.temperature,
    this.deviceId,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] ?? '',
      busNumber: json['busNumber'] ?? '',
      busName: json['busName'] ?? '',
      seatCapacity: _toInt(json['seatCapacity']),
      availableSeats: _toInt(json['availableSeats']),
      status: json['status'] ?? 'STOPPED',
      safetyStatus: json['safetyStatus'] ?? 'SAFE',
      isActive: json['isActive'] ?? false,
      currentLatitude: _toDouble(json['currentLatitude']),
      currentLongitude: _toDouble(json['currentLongitude']),
      temperature: _toDouble(json['temperature']),
      deviceId: json['deviceId'],
    );
  }

  // Firestore may return int or double — handle both safely
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
