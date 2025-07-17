import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/landmark.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FlutterTts _tts = FlutterTts();
  Timer? _locationTimer;

  Position? _currentPosition;
  List<Landmark> _landmarks = [];
  List<Landmark> _nearbyLandmarks = [];
  bool _isTracking = false;

  // Stream controllers for real-time updates
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  final StreamController<List<Landmark>> _nearbyLandmarksController =
      StreamController<List<Landmark>>.broadcast();
  final StreamController<Landmark> _landmarkEnteredController =
      StreamController<Landmark>.broadcast();

  // Getters
  Stream<Position> get positionStream => _positionController.stream;
  Stream<List<Landmark>> get nearbyLandmarksStream =>
      _nearbyLandmarksController.stream;
  Stream<Landmark> get landmarkEnteredStream =>
      _landmarkEnteredController.stream;
  Position? get currentPosition => _currentPosition;
  List<Landmark> get nearbyLandmarks => _nearbyLandmarks;
  bool get isTracking => _isTracking;

  // Initialize the service
  Future<bool> initialize() async {
    try {
      await _initTts();
      await _loadCachedLandmarks();
      await _requestPermissions();
      return true;
    } catch (e) {
      print('LocationService initialization error: $e');
      return false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadCachedLandmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_landmarks');
    if (cachedData != null) {
      // Parse cached landmarks (simplified for now)
      _landmarks = _getDefaultLandmarks();
    } else {
      _landmarks = _getDefaultLandmarks();
      await _cacheLandmarks();
    }
  }

  Future<void> _cacheLandmarks() async {
    final prefs = await SharedPreferences.getInstance();
    // Cache landmarks data (simplified)
    await prefs.setString('cached_landmarks', 'cached');
  }

  Future<bool> _requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _tts.speak(
        "Location services are disabled. Please enable them in settings.",
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _tts.speak(
          "Location permission denied. Cannot provide navigation assistance.",
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _tts.speak(
        "Location permissions permanently denied. Please enable in app settings.",
      );
      return false;
    }

    return true;
  }

  // Start real-time location tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _positionController.add(_currentPosition!);
      await _checkNearbyLandmarks();
    } catch (e) {
      print('Error getting initial position: $e');
    }

    // Start continuous tracking
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _currentPosition = position;
        _positionController.add(position);
        await _checkNearbyLandmarks();
      } catch (e) {
        print('Error updating position: $e');
      }
    });

    await _tts.speak(
      "Location tracking started. I'll guide you through nearby attractions.",
    );
  }

  // Stop location tracking
  Future<void> stopTracking() async {
    _isTracking = false;
    _locationTimer?.cancel();
    await _tts.speak("Location tracking stopped.");
  }

  // Check for nearby landmarks and trigger geofencing
  Future<void> _checkNearbyLandmarks() async {
    if (_currentPosition == null) return;

    final nearby = <Landmark>[];

    for (final landmark in _landmarks) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      if (distance <= landmark.radius) {
        nearby.add(landmark);

        // Check if this is a new landmark entry
        if (!_nearbyLandmarks.contains(landmark)) {
          await _onLandmarkEntered(landmark, distance);
        }
      }
    }

    _nearbyLandmarks = nearby;
    _nearbyLandmarksController.add(nearby);
  }

  // Handle landmark entry
  Future<void> _onLandmarkEntered(Landmark landmark, double distance) async {
    _landmarkEnteredController.add(landmark);

    // Provide audio feedback
    await _tts.speak(
      "You are approaching ${landmark.name}. ${landmark.description} "
      "Distance: ${distance.toStringAsFixed(0)} meters.",
    );

    // Provide haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }

    // Start ambient sound if available
    await _playAmbientSound(landmark.ambientSound);
  }

  // Play ambient sounds
  Future<void> _playAmbientSound(String? soundFile) async {
    if (soundFile != null) {
      // Implementation for ambient sound playback
      // This would integrate with AudioService
      print('Playing ambient sound: $soundFile');
    }
  }

    // Get current location description
  Future<String> getCurrentLocationDescription() async {
    if (_currentPosition == null) {
      return "Location not available";
    }

    // In a real app, you'd use reverse geocoding here
    return "You are at coordinates: ${_currentPosition!.latitude.toStringAsFixed(4)}, "
           "${_currentPosition!.longitude.toStringAsFixed(4)}";
  }

  // Get distance to a specific landmark
  Future<double> getDistanceTo(Landmark landmark) async {
    if (_currentPosition == null) {
      return -1.0; // Invalid distance
    }

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      landmark.latitude,
      landmark.longitude,
    );
  }

  // Provide turn-by-turn navigation
  Future<void> provideNavigationTo(Landmark destination) async {
    if (_currentPosition == null) {
      await _tts.speak("Cannot provide navigation. Location not available.");
      return;
    }

    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      destination.latitude,
      destination.longitude,
    );

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      destination.latitude,
      destination.longitude,
    );

    String direction = _getDirectionFromBearing(bearing);

    await _tts.speak(
      "To reach ${destination.name}, head $direction. "
      "Distance: ${distance.toStringAsFixed(0)} meters.",
    );

    // Provide haptic feedback for direction
    await _provideDirectionalHaptic(bearing);
  }

  String _getDirectionFromBearing(double bearing) {
    if (bearing >= 315 || bearing < 45) return "north";
    if (bearing >= 45 && bearing < 135) return "east";
    if (bearing >= 135 && bearing < 225) return "south";
    return "west";
  }

  Future<void> _provideDirectionalHaptic(double bearing) async {
    if (await Vibration.hasVibrator() ?? false) {
      // Different vibration patterns for different directions
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

  // Get default landmarks (replace with actual data from backend)
  List<Landmark> _getDefaultLandmarks() {
    return [
      Landmark(
        id: '1',
        name: 'Murchison Falls',
        description:
            'One of the most powerful waterfalls in the world, where the Nile River plunges 43 meters.',
        latitude: 2.2783,
        longitude: 31.6809,
        radius: 50.0,
        audioGuide: 'assets/audio/murchison_falls.mp3',
        ambientSound: 'assets/ambient/waterfall.mp3',
        category: 'Natural Wonder',
      ),
      Landmark(
        id: '2',
        name: 'Kampala City Center',
        description:
            'The bustling heart of Uganda\'s capital city with markets and cultural sites.',
        latitude: 0.3476,
        longitude: 32.5825,
        radius: 100.0,
        audioGuide: 'assets/audio/kampala_center.mp3',
        ambientSound: 'assets/ambient/city.mp3',
        category: 'Urban',
      ),
      Landmark(
        id: '3',
        name: 'Lake Victoria Shore',
        description:
            'The largest lake in Africa, offering beautiful views and fishing opportunities.',
        latitude: 0.0000,
        longitude: 33.0000,
        radius: 75.0,
        audioGuide: 'assets/audio/lake_victoria.mp3',
        ambientSound: 'assets/ambient/lake.mp3',
        category: 'Natural',
      ),
    ];
  }

  // Dispose resources
  void dispose() {
    stopTracking();
    _positionController.close();
    _nearbyLandmarksController.close();
    _landmarkEnteredController.close();
  }
}
