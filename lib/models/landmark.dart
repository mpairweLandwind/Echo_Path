class Landmark {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radius; // Geofencing radius in meters
  final String? audioGuide; // Path to audio guide file
  final String? ambientSound; // Path to ambient sound file
  final String category;
  final Map<String, dynamic>? additionalInfo;

  Landmark({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.audioGuide,
    this.ambientSound,
    required this.category,
    this.additionalInfo,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radius: json['radius'].toDouble(),
      audioGuide: json['audioGuide'],
      ambientSound: json['ambientSound'],
      category: json['category'],
      additionalInfo: json['additionalInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'audioGuide': audioGuide,
      'ambientSound': ambientSound,
      'category': category,
      'additionalInfo': additionalInfo,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Landmark && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Landmark(id: $id, name: $name, category: $category)';
  }
}
