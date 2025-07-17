import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/voice_command_service.dart';
import '../services/audio_narration_service.dart';
import '../models/landmark.dart';
import 'dart:async'; // Added for Timer

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  final AudioNarrationService _audioNarrationService = AudioNarrationService();
  final FlutterTts _tts = FlutterTts();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  Position? _currentPosition;
  List<Landmark> _nearbyLandmarks = [];
  Set<Marker> _markers = {};
  bool _isTracking = false;
  bool _isListening = false;

  // Navigation and voice narration state
  bool _isNavigating = false;
  Landmark? _navigationTarget;
  Timer? _narrationTimer;
  String _lastNarratedLocation = '';
  double _lastNarratedBearing = 0.0;

  // Map settings
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(0.3476, 32.5825), // Kampala, Uganda
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _listenToOtherUsers();
    _startContinuousNarration();
  }

  Future<void> _initializeServices() async {
    try {
      await _locationService.initialize();
      await _voiceCommandService.initialize();
      await _audioNarrationService.initialize();
      await _initTts();

      // Get initial position to center the map
      final initialPosition = await _locationService.getInitialPosition();
      setState(() {
        _currentPosition = initialPosition;
      });
      _centerMapOnUser();

      // Listen to location updates
      _locationService.positionStream.listen(_onPositionUpdate);
      _locationService.nearbyLandmarksStream.listen(_onNearbyLandmarksUpdate);
      _locationService.landmarkEnteredStream.listen(_onLandmarkEntered);

      // Listen to voice commands for UI
      _voiceCommandService.uiCommandStream.listen(_onUiCommand);

      // Start location tracking
      await _startLocationTracking();

      // Start audio narration
      _audioNarrationService.startNarration();

      if (mounted) {
        await _tts.speak(
          "Map screen loaded. I'll provide comprehensive voice guidance describing your surroundings, landmarks, and navigation cues.",
        );
      }
    } catch (e) {
      print('Error initializing map services: $e');
      if (mounted) {
        await _tts.speak(
          "Error initializing map services. Please check your location permissions.",
        );
      }
    }
  }

  void _centerMapOnUser() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  void _onUiCommand(String command) {
    if (command == 'center_map') {
      _centerMapOnUser();
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _startLocationTracking() async {
    await _locationService.startTracking();
    setState(() {
      _isTracking = true;
    });
  }

  void _startContinuousNarration() {
    // Narrate surroundings every 10 seconds when moving
    _narrationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isTracking && _currentPosition != null) {
        _narrateSurroundings();
      }
    });
  }

  Future<void> _narrateSurroundings() async {
    if (_currentPosition == null) return;

    // Get current location description
    final locationDesc = await _getLocationDescription();

    // Get nearby features
    final nearbyFeatures = await _getNearbyFeatures();

    // Get navigation information if navigating
    String navigationInfo = '';
    if (_isNavigating && _navigationTarget != null) {
      navigationInfo = await _getNavigationInfo();
    }

    // Combine all information for narration
    String narration = '';
    if (locationDesc != _lastNarratedLocation) {
      narration += locationDesc;
      _lastNarratedLocation = locationDesc;
    }

    if (nearbyFeatures.isNotEmpty) {
      narration += ' Nearby: $nearbyFeatures';
    }

    if (navigationInfo.isNotEmpty) {
      narration += ' Navigation: $navigationInfo';
    }

    if (narration.isNotEmpty) {
      await _tts.speak(narration);
    }
  }

  Future<String> _getLocationDescription() async {
    // In a real app, you'd use reverse geocoding here
    // For now, provide coordinate-based description
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    // Determine general area based on coordinates
    String area = 'unknown area';
    if (lat > 2.0 && lat < 2.5 && lng > 31.5 && lng < 32.0) {
      area = 'Murchison Falls area';
    } else if (lat > 0.3 && lat < 0.4 && lng > 32.5 && lng < 32.6) {
      area = 'Kampala city center';
    } else if (lat > -0.1 && lat < 0.1 && lng > 32.9 && lng < 33.1) {
      area = 'Lake Victoria shore';
    }

    return 'You are in $area at coordinates ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<String> _getNearbyFeatures() async {
    List<String> features = [];

    // Add nearby landmarks
    for (final landmark in _nearbyLandmarks) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      if (distance <= 200) {
        // Within 200 meters
        features.add(
          '${landmark.name} ${distance.toStringAsFixed(0)} meters away',
        );
      }
    }

    // Add street information (simulated)
    features.add('Main street ahead');
    features.add('Intersection 50 meters ahead');

    // Add other users nearby
    for (final marker in _markers) {
      if (marker.markerId.value.startsWith('user_') &&
          marker.markerId.value != 'user_location') {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          marker.position.latitude,
          marker.position.longitude,
        );

        if (distance <= 100) {
          features.add(
            'Another user ${distance.toStringAsFixed(0)} meters away',
          );
        }
      }
    }

    return features.join(', ');
  }

  Future<String> _getNavigationInfo() async {
    if (_navigationTarget == null || _currentPosition == null) return '';

    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    String direction = _getDirectionFromBearing(bearing);

    // Check if bearing has changed significantly
    if ((bearing - _lastNarratedBearing).abs() > 30) {
      _lastNarratedBearing = bearing;
      return 'Turn $direction towards ${_navigationTarget!.name}. Distance: ${distance.toStringAsFixed(0)} meters';
    }

    return 'Continue $direction. ${distance.toStringAsFixed(0)} meters to ${_navigationTarget!.name}';
  }

  String _getDirectionFromBearing(double bearing) {
    if (bearing >= 315 || bearing < 45) return "north";
    if (bearing >= 45 && bearing < 135) return "east";
    if (bearing >= 135 && bearing < 225) return "south";
    return "west";
  }

  Future<void> _updateUserLocationInFirestore(Position position) async {
    _userId ??= DateTime.now().millisecondsSinceEpoch.toString();
    await _firestore.collection('user_locations').doc(_userId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _listenToOtherUsers() {
    _firestore.collection('user_locations').snapshots().listen((snapshot) {
      final Set<Marker> newMarkers = {..._markers};
      for (var doc in snapshot.docs) {
        if (doc.id == _userId) continue;
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('user_${doc.id}'),
              position: LatLng(data['latitude'], data['longitude']),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: const InfoWindow(title: 'Other User'),
              onTap: () async {
                await _tts.speak(
                  "Another user is nearby at latitude ${data['latitude'].toStringAsFixed(4)}, longitude ${data['longitude'].toStringAsFixed(4)}",
                );
              },
            ),
          );
        }
      }
      setState(() {
        _markers = newMarkers;
      });
    });
  }

  void _onPositionUpdate(Position position) {
    setState(() {
      _currentPosition = position;
    });

    // Update audio narration service
    _audioNarrationService.updatePosition(position);

    // Update map camera to follow user
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );

    // Update user marker
    _updateMarkers();

    // Update Firestore
    _updateUserLocationInFirestore(position);

    // Provide immediate location feedback
    _tts.speak("Location updated. ${_getLocationDescription()}");
  }

  void _onNearbyLandmarksUpdate(List<Landmark> landmarks) {
    setState(() {
      _nearbyLandmarks = landmarks;
    });

    // Update audio narration service
    _audioNarrationService.updateLandmarks(landmarks);

    _updateMarkers();

    // Announce new landmarks
    for (final landmark in landmarks) {
      if (!_nearbyLandmarks.contains(landmark)) {
        _tts.speak("New landmark detected: ${landmark.name}");
      }
    }
  }

  void _onLandmarkEntered(Landmark landmark) {
    // This is handled by the location service with TTS and haptic feedback
    print('Entered landmark: ${landmark.name}');
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Add user location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add landmark markers
    for (final landmark in _nearbyLandmarks) {
      markers.add(
        Marker(
          markerId: MarkerId(landmark.id),
          position: LatLng(landmark.latitude, landmark.longitude),
          infoWindow: InfoWindow(
            title: landmark.name,
            snippet: landmark.description,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _onLandmarkTapped(landmark),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _onLandmarkTapped(Landmark landmark) async {
    await _tts.speak("${landmark.name}. ${landmark.description}");

    // Provide haptic feedback
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 300);
    }

    // Start navigation to this landmark
    await _startNavigationTo(landmark);
  }

  Future<void> _startNavigationTo(Landmark landmark) async {
    setState(() {
      _isNavigating = true;
      _navigationTarget = landmark;
    });

    await _tts.speak(
      "Starting navigation to ${landmark.name}. I'll guide you there.",
    );

    // Provide initial navigation instructions
    await _provideNavigationInstructions();
  }

  Future<void> _provideNavigationInstructions() async {
    if (_navigationTarget == null || _currentPosition == null) return;

    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    String direction = _getDirectionFromBearing(bearing);

    await _tts.speak(
      "To reach ${_navigationTarget!.name}, head $direction. "
      "Distance: ${distance.toStringAsFixed(0)} meters. "
      "I'll provide turn-by-turn guidance as you move.",
    );

    // Provide haptic feedback for direction
    await _provideDirectionalHaptic(bearing);
  }

  Future<void> _provideDirectionalHaptic(double bearing) async {
    if (await Vibration.hasVibrator()) {
      if (bearing >= 315 || bearing < 45) {
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 45 && bearing < 135) {
        Vibration.vibrate(duration: 200);
        await Future.delayed(Duration(milliseconds: 300));
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 135 && bearing < 225) {
        for (int i = 0; i < 3; i++) {
          Vibration.vibrate(duration: 200);
          await Future.delayed(Duration(milliseconds: 200));
        }
      } else {
        Vibration.vibrate(duration: 500);
      }
    }
  }

  Future<void> _toggleVoiceCommands() async {
    if (_isListening) {
      await _voiceCommandService.stopListening();
      setState(() {
        _isListening = false;
      });
      await _tts.speak("Voice commands stopped.");
    } else {
      await _voiceCommandService.startListening();
      setState(() {
        _isListening = true;
      });
      await _tts.speak(
        "Voice commands activated. Say 'help' for available commands.",
      );
    }
  }

  Future<void> _speakCurrentLocation() async {
    if (_currentPosition != null) {
      final description = await _getLocationDescription();
      await _tts.speak(description);
    } else {
      await _tts.speak("Location not available yet. Please wait.");
    }
  }

  Future<void> _speakNearbyAttractions() async {
    if (_nearbyLandmarks.isEmpty) {
      await _tts.speak(
        "No attractions are currently nearby. Try moving around to discover places.",
      );
    } else {
      String response = "Nearby attractions: ";
      for (final landmark in _nearbyLandmarks) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          landmark.latitude,
          landmark.longitude,
        );
        response +=
            "${landmark.name} ${distance.toStringAsFixed(0)} meters away, ";
      }
      response +=
          "Tap on any marker or say 'navigate to' followed by the attraction name.";
      await _tts.speak(response);
    }
  }

  Future<void> _stopNavigation() async {
    setState(() {
      _isNavigating = false;
      _navigationTarget = null;
    });
    await _tts.speak("Navigation stopped.");
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _voiceCommandService.stopListening();
    _audioNarrationService.stopNarration();
    _narrationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EchoPath Map'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
            onPressed: _toggleVoiceCommands,
            tooltip: 'Toggle Voice Commands',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  )
                : _defaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onTap: (LatLng position) async {
              await _tts.speak(
                "Map tapped at coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}",
              );
            },
          ),

          // Status overlay
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTracking ? Icons.location_on : Icons.location_off,
                    color: _isTracking ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTracking
                          ? 'Location tracking active'
                          : 'Location tracking inactive',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (_isListening)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'VOICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_isNavigating)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NAV',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Control buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'center_map',
                  onPressed: _centerMapOnUser,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'attractions',
                  onPressed: _speakNearbyAttractions,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.place, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'voice_toggle',
                  onPressed: _toggleVoiceCommands,
                  backgroundColor: _isListening ? Colors.red : Colors.orange,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                ),
                if (_isNavigating) ...[
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'stop_nav',
                    onPressed: _stopNavigation,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),

          // Nearby landmarks list
          if (_nearbyLandmarks.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(0, 0, 0, 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _nearbyLandmarks.length,
                  itemBuilder: (context, index) {
                    final landmark = _nearbyLandmarks[index];
                    return ListTile(
                      title: Text(
                        landmark.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        landmark.category,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      onTap: () => _onLandmarkTapped(landmark),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
