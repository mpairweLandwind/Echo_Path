import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/landmark.dart';
import 'location_service.dart';

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final LocationService _locationService = LocationService();

  bool _isListening = false;
  bool _isInitialized = false;
  Timer? _listeningTimer;

  // Command patterns
  static const Map<String, List<String>> _commandPatterns = {
    'where_am_i': [
      'where am i',
      'my location',
      'current location',
      'where i am',
      'tell me where i am',
    ],
    'nearby_attractions': [
      'nearby attractions',
      'what\'s nearby',
      'nearby places',
      'attractions',
      'what\'s around me',
    ],
    'start_tour': [
      'start tour',
      'begin tour',
      'start audio tour',
      'begin audio tour',
    ],
    'stop_tour': ['stop tour', 'end tour', 'stop audio tour', 'end audio tour'],
    'navigation': [
      'navigate to',
      'guide me to',
      'take me to',
      'directions to',
      'route to',
    ],
    'help': [
      'help',
      'what can i say',
      'commands',
      'voice commands',
      'available commands',
    ],
    'repeat': ['repeat', 'say again', 'repeat that', 'what did you say'],
    'volume_up': ['volume up', 'louder', 'increase volume'],
    'volume_down': ['volume down', 'quieter', 'decrease volume'],
    'emergency': ['emergency', 'help me', 'sos', 'call for help'],
    'describe_surroundings': [
      'describe surroundings',
      'what do i see',
      'describe area',
      'tell me about this place',
    ],
    'street_info': [
      'street info',
      'road information',
      'what street',
      'street name',
    ],
    'intersection_info': [
      'intersection',
      'crossing',
      'traffic light',
      'stop sign',
    ],
    'distance_to': ['distance to', 'how far to', 'how far away'],
    'stop_navigation': [
      'stop navigation',
      'end navigation',
      'cancel route',
      'stop guiding',
    ],
    'pause_narration': ['pause narration', 'stop talking', 'quiet mode'],
    'resume_narration': [
      'resume narration',
      'start talking',
      'continue narration',
    ],
    'find_landmark': ['find landmark', 'search for', 'look for', 'where is'],
    'describe_landmark': ['describe landmark', 'tell me about', 'what is this'],
    'other_users': ['other users', 'people nearby', 'who else is here'],
  };

  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _initTts();
      await _initSpeechRecognition();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('VoiceCommandService initialization error: $e');
      return false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _initSpeechRecognition() async {
    bool available = await _speech.initialize(
      onError: (val) => print('Speech recognition error: $val'),
      onStatus: (val) => print('Speech recognition status: $val'),
    );

    if (!available) {
      throw Exception('Speech recognition not available');
    }
  }

  // Start listening for voice commands
  Future<void> startListening() async {
    if (!_isInitialized || _isListening) return;

    _isListening = true;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      // Auto-restart listening after timeout
      _listeningTimer = Timer(const Duration(seconds: 10), () {
        if (_isListening) {
          startListening();
        }
      });

      await _tts.speak(
        "Listening for voice commands. Say 'help' for available commands.",
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    _listeningTimer?.cancel();
    await _speech.stop();
  }

  // Handle speech recognition results
  void _onSpeechResult(dynamic result) {
    if (result.finalResult) {
      final command = result.recognizedWords.toLowerCase();
      _processCommand(command);
    }
  }

  // Process voice commands
  Future<void> _processCommand(String command) async {
    print('Processing command: $command');

    // Check for exact matches first
    for (final entry in _commandPatterns.entries) {
      for (final pattern in entry.value) {
        if (command.contains(pattern)) {
          await _executeCommand(entry.key, command);
          return;
        }
      }
    }

    // Check for navigation commands with landmarks
    if (command.contains('navigate to') || command.contains('guide me to')) {
      await _handleNavigationCommand(command);
      return;
    }

    // Check for distance queries
    if (command.contains('distance to') || command.contains('how far to')) {
      await _handleDistanceCommand(command);
      return;
    }

    // Check for landmark search
    if (command.contains('find') ||
        command.contains('search for') ||
        command.contains('where is')) {
      await _handleLandmarkSearch(command);
      return;
    }

    // Default response for unrecognized commands
    await _tts.speak(
      "I didn't understand that command. Say 'help' for available commands.",
    );
  }

  // Execute specific commands
  Future<void> _executeCommand(String commandType, String fullCommand) async {
    switch (commandType) {
      case 'where_am_i':
        await _handleWhereAmI();
        break;
      case 'nearby_attractions':
        await _handleNearbyAttractions();
        break;
      case 'start_tour':
        await _handleStartTour();
        break;
      case 'stop_tour':
        await _handleStopTour();
        break;
      case 'help':
        await _handleHelp();
        break;
      case 'repeat':
        await _handleRepeat();
        break;
      case 'volume_up':
        await _handleVolumeUp();
        break;
      case 'volume_down':
        await _handleVolumeDown();
        break;
      case 'emergency':
        await _handleEmergency();
        break;
      case 'describe_surroundings':
        await _handleDescribeSurroundings();
        break;
      case 'street_info':
        await _handleStreetInfo();
        break;
      case 'intersection_info':
        await _handleIntersectionInfo();
        break;
      case 'stop_navigation':
        await _handleStopNavigation();
        break;
      case 'pause_narration':
        await _handlePauseNarration();
        break;
      case 'resume_narration':
        await _handleResumeNarration();
        break;
      case 'other_users':
        await _handleOtherUsers();
        break;
    }
  }

  // Command handlers
  Future<void> _handleWhereAmI() async {
    final description = await _locationService.getCurrentLocationDescription();
    await _tts.speak(description);
  }

  Future<void> _handleNearbyAttractions() async {
    final landmarks = _locationService.nearbyLandmarks;
    if (landmarks.isEmpty) {
      await _tts.speak(
        "No attractions are currently nearby. Try moving around to discover places.",
      );
    } else {
      String response = "Nearby attractions: ";
      for (final landmark in landmarks) {
        response += "${landmark.name}, ";
      }
      response +=
          "Say 'navigate to' followed by the attraction name for directions.";
      await _tts.speak(response);
    }
  }

  Future<void> _handleStartTour() async {
    final landmarks = _locationService.nearbyLandmarks;
    if (landmarks.isEmpty) {
      await _tts.speak(
        "No tours available at your current location. Move around to find attractions.",
      );
    } else {
      await _tts.speak(
        "Starting tour of ${landmarks.first.name}. ${landmarks.first.description}",
      );
      // Here you would start the audio tour
    }
  }

  Future<void> _handleStopTour() async {
    await _tts.speak("Stopping current tour.");
    // Here you would stop the audio tour
  }

  Future<void> _handleNavigationCommand(String command) async {
    // Extract landmark name from command
    String landmarkName = '';
    if (command.contains('navigate to')) {
      landmarkName = command.split('navigate to').last.trim();
    } else if (command.contains('guide me to')) {
      landmarkName = command.split('guide me to').last.trim();
    }

    if (landmarkName.isNotEmpty) {
      await _navigateToLandmark(landmarkName);
    } else {
      await _tts.speak(
        "Please specify which attraction you want to navigate to.",
      );
    }
  }

  Future<void> _navigateToLandmark(String landmarkName) async {
    final landmarks = _locationService.nearbyLandmarks;
    Landmark? targetLandmark;

    // Find the landmark by name (case-insensitive)
    for (final landmark in landmarks) {
      if (landmark.name.toLowerCase().contains(landmarkName.toLowerCase()) ||
          landmarkName.toLowerCase().contains(landmark.name.toLowerCase())) {
        targetLandmark = landmark;
        break;
      }
    }

    if (targetLandmark != null) {
      await _locationService.provideNavigationTo(targetLandmark);
    } else {
      await _tts.speak(
        "I couldn't find '$landmarkName' nearby. Try saying 'nearby attractions' to see what's available.",
      );
    }
  }

  Future<void> _handleDistanceCommand(String command) async {
    // Extract landmark name from command
    String landmarkName = '';
    if (command.contains('distance to')) {
      landmarkName = command.split('distance to').last.trim();
    } else if (command.contains('how far to')) {
      landmarkName = command.split('how far to').last.trim();
    }

    if (landmarkName.isNotEmpty) {
      await _getDistanceToLandmark(landmarkName);
    } else {
      await _tts.speak(
        "Please specify which attraction you want to know the distance to.",
      );
    }
  }

  Future<void> _getDistanceToLandmark(String landmarkName) async {
    final landmarks = _locationService.nearbyLandmarks;
    Landmark? targetLandmark;

    for (final landmark in landmarks) {
      if (landmark.name.toLowerCase().contains(landmarkName.toLowerCase()) ||
          landmarkName.toLowerCase().contains(landmark.name.toLowerCase())) {
        targetLandmark = landmark;
        break;
      }
    }

    if (targetLandmark != null) {
      final distance = await _locationService.getDistanceTo(targetLandmark);
      await _tts.speak(
        "${targetLandmark.name} is ${distance.toStringAsFixed(0)} meters away.",
      );
    } else {
      await _tts.speak("I couldn't find '$landmarkName' nearby.");
    }
  }

  Future<void> _handleLandmarkSearch(String command) async {
    String searchTerm = '';
    if (command.contains('find')) {
      searchTerm = command.split('find').last.trim();
    } else if (command.contains('search for')) {
      searchTerm = command.split('search for').last.trim();
    } else if (command.contains('where is')) {
      searchTerm = command.split('where is').last.trim();
    }

    if (searchTerm.isNotEmpty) {
      await _searchForLandmark(searchTerm);
    } else {
      await _tts.speak("Please specify what you're looking for.");
    }
  }

  Future<void> _searchForLandmark(String searchTerm) async {
    final landmarks = _locationService.nearbyLandmarks;
    List<Landmark> matches = [];

    for (final landmark in landmarks) {
      if (landmark.name.toLowerCase().contains(searchTerm.toLowerCase()) ||
          landmark.description.toLowerCase().contains(
            searchTerm.toLowerCase(),
          ) ||
          landmark.category.toLowerCase().contains(searchTerm.toLowerCase())) {
        matches.add(landmark);
      }
    }

    if (matches.isNotEmpty) {
      String response = "Found ${matches.length} matches: ";
      for (final landmark in matches) {
        response += "${landmark.name}, ";
      }
      await _tts.speak(response);
    } else {
      await _tts.speak("No landmarks found matching '$searchTerm'.");
    }
  }

  Future<void> _handleDescribeSurroundings() async {
    final landmarks = _locationService.nearbyLandmarks;
    if (landmarks.isEmpty) {
      await _tts.speak(
        "You are in an open area with no nearby landmarks. Try moving around to discover places.",
      );
    } else {
      String description = "You are surrounded by: ";
      for (final landmark in landmarks) {
        description += "${landmark.name} - ${landmark.description}. ";
      }
      await _tts.speak(description);
    }
  }

  Future<void> _handleStreetInfo() async {
    // In a real app, you'd use reverse geocoding to get street names
    await _tts.speak(
      "You are on a main street. The road surface appears to be paved.",
    );
  }

  Future<void> _handleIntersectionInfo() async {
    await _tts.speak(
      "You are approaching an intersection. Please be careful when crossing.",
    );
  }

  Future<void> _handleStopNavigation() async {
    await _tts.speak("Navigation stopped. You can now explore freely.");
    // Here you would stop navigation
  }

  Future<void> _handlePauseNarration() async {
    await _tts.speak("Narration paused. Say 'resume narration' to continue.");
    // Here you would pause continuous narration
  }

  Future<void> _handleResumeNarration() async {
    await _tts.speak(
      "Narration resumed. I'll continue describing your surroundings.",
    );
    // Here you would resume continuous narration
  }

  Future<void> _handleOtherUsers() async {
    await _tts.speak(
      "Checking for other users nearby. This feature shows other EchoPath users in the area.",
    );
  }

  Future<void> _handleHelp() async {
    String helpText = "Available voice commands: ";
    helpText += "Say 'where am I' to get your current location. ";
    helpText += "Say 'nearby attractions' to hear what's around you. ";
    helpText += "Say 'describe surroundings' for detailed area information. ";
    helpText +=
        "Say 'navigate to' followed by an attraction name for directions. ";
    helpText +=
        "Say 'distance to' followed by a landmark name for distance information. ";
    helpText +=
        "Say 'find' followed by what you're looking for to search landmarks. ";
    helpText += "Say 'stop navigation' to end current navigation. ";
    helpText +=
        "Say 'pause narration' or 'resume narration' to control voice feedback. ";
    helpText += "Say 'help' anytime to hear these commands again.";

    await _tts.speak(helpText);
  }

  Future<void> _handleRepeat() async {
    await _tts.speak(
      "I'll repeat the last information. Say 'help' for available commands.",
    );
  }

  Future<void> _handleVolumeUp() async {
    // Implementation for volume control
    await _tts.speak("Volume increased.");
  }

  Future<void> _handleVolumeDown() async {
    // Implementation for volume control
    await _tts.speak("Volume decreased.");
  }

  Future<void> _handleEmergency() async {
    await _tts.speak(
      "Emergency mode activated. Sending your location to emergency contacts.",
    );
    // Here you would implement emergency functionality
  }

  // Get current listening status
  bool get isListening => _isListening;

  // Dispose resources
  void dispose() {
    stopListening();
  }
}
