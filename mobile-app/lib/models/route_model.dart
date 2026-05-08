class BusRoute {
  final String id;
  final String busId;
  final String busNumber;
  final String busName;
  final String source;
  final String destination;
  final List<Stop> intermediateStops;
  final String? departureTime;
  final String? arrivalTime;
  final String? serviceNumber;
  final bool isActive;

  BusRoute({
    required this.id,
    required this.busId,
    required this.busNumber,
    required this.busName,
    required this.source,
    required this.destination,
    required this.intermediateStops,
    this.departureTime,
    this.arrivalTime,
    this.serviceNumber,
    required this.isActive,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] ?? '',
      busId: json['busId'] ?? '',
      busNumber: json['busNumber'] ?? '',
      busName: json['busName'] ?? '',
      source: json['source'] ?? '',
      destination: json['destination'] ?? '',
      intermediateStops: (json['intermediateStops'] as List<dynamic>?)
              ?.map((s) => Stop.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
      departureTime: json['departureTime'],
      arrivalTime: json['arrivalTime'],
      serviceNumber: json['serviceNumber'],
      isActive: json['isActive'] ?? true,
    );
  }
}

class Stop {
  final String name;
  final String? arrivalTime;
  final int orderIndex;
  final double latitude;
  final double longitude;

  Stop({
    required this.name,
    this.arrivalTime,
    required this.orderIndex,
    required this.latitude,
    required this.longitude,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      name: json['name'] ?? '',
      arrivalTime: json['arrivalTime'],
      orderIndex: _toInt(json['orderIndex']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

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
