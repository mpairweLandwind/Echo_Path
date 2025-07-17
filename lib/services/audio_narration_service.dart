import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../models/landmark.dart';

class AudioNarrationService {
  static final AudioNarrationService _instance =
      AudioNarrationService._internal();
  factory AudioNarrationService() => _instance;
  AudioNarrationService._internal();

  final FlutterTts _tts = FlutterTts();
  Timer? _narrationTimer;
  bool _isNarrating = false;
  bool _isPaused = false;

  // Narration state
  String _lastNarratedLocation = '';
  double _lastNarratedBearing = 0.0;
  Position? _currentPosition;
  List<Landmark> _nearbyLandmarks = [];

  // Narration settings
  static const Duration _narrationInterval = Duration(seconds: 15);
  static const double _bearingChangeThreshold = 30.0; // degrees
  static const double _distanceThreshold = 50.0; // meters

  // Initialize the service
  Future<void> initialize() async {
    await _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // Start continuous narration
  void startNarration() {
    if (_isNarrating) return;

    _isNarrating = true;
    _isPaused = false;

    _narrationTimer = Timer.periodic(_narrationInterval, (timer) {
      if (!_isPaused && _currentPosition != null) {
        _narrateSurroundings();
      }
    });
  }

  // Stop narration
  void stopNarration() {
    _isNarrating = false;
    _isPaused = false;
    _narrationTimer?.cancel();
  }

  // Pause/resume narration
  void pauseNarration() {
    _isPaused = true;
  }

  void resumeNarration() {
    _isPaused = false;
  }

  // Update current position and landmarks
  void updatePosition(Position position) {
    _currentPosition = position;
  }

  void updateLandmarks(List<Landmark> landmarks) {
    _nearbyLandmarks = landmarks;
  }

  // Main narration method
  Future<void> _narrateSurroundings() async {
    if (_currentPosition == null) return;

    final List<String> narrationParts = [];

    // Location description
    final locationDesc = await _getLocationDescription();
    if (locationDesc != _lastNarratedLocation) {
      narrationParts.add(locationDesc);
      _lastNarratedLocation = locationDesc;
    }

    // Nearby features
    final nearbyFeatures = await _getNearbyFeatures();
    if (nearbyFeatures.isNotEmpty) {
      narrationParts.add("Nearby: $nearbyFeatures");
    }

    // Street and intersection information
    final streetInfo = await _getStreetInformation();
    if (streetInfo.isNotEmpty) {
      narrationParts.add(streetInfo);
    }

    // Safety information
    final safetyInfo = await _getSafetyInformation();
    if (safetyInfo.isNotEmpty) {
      narrationParts.add(safetyInfo);
    }

    // Combine and speak
    if (narrationParts.isNotEmpty) {
      final fullNarration = narrationParts.join('. ');
      await _tts.speak(fullNarration);
    }
  }

  // Get detailed location description
  Future<String> _getLocationDescription() async {
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    // Determine area based on coordinates
    String area = _getAreaName(lat, lng);
    String elevation = await _getElevationDescription();

    return "You are in $area at coordinates ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}. $elevation";
  }

  String _getAreaName(double lat, double lng) {
    if (lat > 2.0 && lat < 2.5 && lng > 31.5 && lng < 32.0) {
      return "Murchison Falls National Park area";
    } else if (lat > 0.3 && lat < 0.4 && lng > 32.5 && lng < 32.6) {
      return "Kampala city center";
    } else if (lat > -0.1 && lat < 0.1 && lng > 32.9 && lng < 33.1) {
      return "Lake Victoria shoreline";
    } else if (lat > 0.0 && lat < 0.5 && lng > 32.0 && lng < 33.0) {
      return "Central Uganda region";
    }
    return "an unknown area";
  }

  Future<String> _getElevationDescription() async {
    final altitude = _currentPosition!.altitude;
    if (altitude > 1000) {
      return "You are at a high elevation of ${altitude.toStringAsFixed(0)} meters above sea level.";
    } else if (altitude > 500) {
      return "You are at a moderate elevation of ${altitude.toStringAsFixed(0)} meters above sea level.";
    } else {
      return "You are at a low elevation of ${altitude.toStringAsFixed(0)} meters above sea level.";
    }
  }

  // Get nearby features description
  Future<String> _getNearbyFeatures() async {
    List<String> features = [];

    // Add nearby landmarks with distances
    for (final landmark in _nearbyLandmarks) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      if (distance <= 300) {
        // Within 300 meters
        String distanceDesc = _getDistanceDescription(distance);
        features.add("${landmark.name} $distanceDesc");
      }
    }

    // Add natural features (simulated)
    final naturalFeatures = await _getNaturalFeatures();
    features.addAll(naturalFeatures);

    return features.join(', ');
  }

  String _getDistanceDescription(double distance) {
    if (distance < 50) {
      return "very close, ${distance.toStringAsFixed(0)} meters away";
    } else if (distance < 100) {
      return "close by, ${distance.toStringAsFixed(0)} meters away";
    } else if (distance < 200) {
      return "nearby, ${distance.toStringAsFixed(0)} meters away";
    } else {
      return "in the area, ${distance.toStringAsFixed(0)} meters away";
    }
  }

  Future<List<String>> _getNaturalFeatures() async {
    List<String> features = [];

    // Simulate natural feature detection based on location
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    if (lat > 2.0 && lat < 2.5 && lng > 31.5 && lng < 32.0) {
      features.add("dense forest vegetation");
      features.add("wildlife sounds in the distance");
    } else if (lat > 0.3 && lat < 0.4 && lng > 32.5 && lng < 32.6) {
      features.add("urban environment");
      features.add("traffic sounds");
    } else if (lat > -0.1 && lat < 0.1 && lng > 32.9 && lng < 33.1) {
      features.add("water sounds");
      features.add("lake breeze");
    }

    return features;
  }

  // Get street and intersection information
  Future<String> _getStreetInformation() async {
    List<String> streetInfo = [];

    // Simulate street detection
    final speed = _currentPosition!.speed;
    if (speed > 0) {
      streetInfo.add(
        "You are moving at ${(speed * 3.6).toStringAsFixed(1)} kilometers per hour",
      );
    }

    // Add intersection information
    final intersectionInfo = await _getIntersectionInfo();
    if (intersectionInfo.isNotEmpty) {
      streetInfo.add(intersectionInfo);
    }

    // Add road surface information
    final roadSurface = await _getRoadSurfaceInfo();
    if (roadSurface.isNotEmpty) {
      streetInfo.add(roadSurface);
    }

    return streetInfo.join('. ');
  }

  Future<String> _getIntersectionInfo() async {
    // Simulate intersection detection
    final accuracy = _currentPosition!.accuracy;
    if (accuracy < 10) {
      return "High accuracy GPS indicates you are on a well-defined path";
    } else if (accuracy < 20) {
      return "Moderate GPS accuracy suggests you are in an open area";
    } else {
      return "Low GPS accuracy, you may be near buildings or under tree cover";
    }
  }

  Future<String> _getRoadSurfaceInfo() async {
    // Simulate road surface detection
    final altitude = _currentPosition!.altitude;
    if (altitude > 1000) {
      return "You are on elevated terrain, likely a hill or mountain path";
    } else {
      return "You are on relatively flat terrain";
    }
  }

  // Get safety information
  Future<String> _getSafetyInformation() async {
    List<String> safetyInfo = [];

    // Check for potential hazards
    final speed = _currentPosition!.speed;
    if (speed > 5) {
      // Moving faster than walking speed
      safetyInfo.add(
        "You appear to be moving quickly, please be aware of your surroundings",
      );
    }

    // Check for nearby landmarks that might indicate safety concerns
    for (final landmark in _nearbyLandmarks) {
      if (landmark.category.toLowerCase().contains('water') ||
          landmark.name.toLowerCase().contains('falls') ||
          landmark.name.toLowerCase().contains('lake')) {
        safetyInfo.add("Water feature nearby, exercise caution");
        break;
      }
    }

    return safetyInfo.join('. ');
  }

  // Navigation-specific narration
  Future<void> narrateNavigationUpdate(
    Landmark destination,
    double bearing,
    double distance,
  ) async {
    String narration = "";

    // Check if bearing has changed significantly
    if ((bearing - _lastNarratedBearing).abs() > _bearingChangeThreshold) {
      String direction = _getDirectionFromBearing(bearing);
      narration += "Turn $direction towards ${destination.name}. ";
      _lastNarratedBearing = bearing;
    }

    // Provide distance updates
    if (distance < _distanceThreshold) {
      narration +=
          "You are very close to ${destination.name}, ${distance.toStringAsFixed(0)} meters away.";
    } else if (distance < 100) {
      narration +=
          "Continue towards ${destination.name}, ${distance.toStringAsFixed(0)} meters remaining.";
    } else {
      narration +=
          "Distance to ${destination.name}: ${distance.toStringAsFixed(0)} meters.";
    }

    if (narration.isNotEmpty) {
      await _tts.speak(narration);
      await _provideDirectionalHaptic(bearing);
    }
  }

  String _getDirectionFromBearing(double bearing) {
    if (bearing >= 315 || bearing < 45) return "north";
    if (bearing >= 45 && bearing < 135) return "east";
    if (bearing >= 135 && bearing < 225) return "south";
    return "west";
  }

  Future<void> _provideDirectionalHaptic(double bearing) async {
    if (await Vibration.hasVibrator()) {
      if (bearing >= 315 || bearing < 45) {
        // North - single vibration
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 45 && bearing < 135) {
        // East - double vibration
        Vibration.vibrate(duration: 200);
        await Future.delayed(Duration(milliseconds: 300));
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 135 && bearing < 225) {
        // South - triple vibration
        for (int i = 0; i < 3; i++) {
          Vibration.vibrate(duration: 200);
          await Future.delayed(Duration(milliseconds: 200));
        }
      } else {
        // West - long vibration
        Vibration.vibrate(duration: 500);
      }
    }
  }

  // Landmark-specific narration
  Future<void> narrateLandmarkApproach(
    Landmark landmark,
    double distance,
  ) async {
    String narration = "Approaching ${landmark.name}. ";
    narration += landmark.description;
    narration += " Distance: ${distance.toStringAsFixed(0)} meters.";

    await _tts.speak(narration);

    // Provide haptic feedback
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }
  }

  // Emergency narration
  Future<void> narrateEmergency(String emergencyType) async {
    String narration = "Emergency alert: $emergencyType. ";
    narration += "Your location has been logged. ";
    narration += "Please stay calm and follow safety procedures.";

    await _tts.speak(narration);

    // Emergency haptic pattern
    if (await Vibration.hasVibrator()) {
      for (int i = 0; i < 5; i++) {
        Vibration.vibrate(duration: 1000);
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
  }

  // Get narration status
  bool get isNarrating => _isNarrating;
  bool get isPaused => _isPaused;

  // Dispose resources
  void dispose() {
    stopNarration();
  }
}
