import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:developer' as developer;

import "tour_discovery_screen.dart";
import "downloads_screen.dart";
import "help_and_support_screen.dart";
import "screens/map_screen.dart";

class AppScaffold extends StatefulWidget {
  final int selectedIndex;
  final Widget child;
  final Function(int)? onTabChanged;
  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.onTabChanged,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late FlutterTts tts;

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();
  }

  Future<void> _speakTabInfo(int index) async {
    String message;
    switch (index) {
      case 0:
        message =
            "Home. This is your main dashboard. You can access all features from here.";
        break;
      case 1:
        message =
            "Map. Interactive map with real-time location tracking and voice-guided navigation.";
        break;
      case 2:
        message =
            "Discover. Find and start tours for nearby attractions using your location.";
        break;
      case 3:
        message = "Downloads. Listen to tours you have saved for offline use.";
        break;
      case 4:
        message = "Help and Support. Get tips, FAQs, and voice command help.";
        break;
      default:
        message = "Tab selected.";
    }
    await tts.speak(message);
  }

  void _onItemTapped(int index) {
    _speakTabInfo(index);
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        iconSize: 24,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help),
            label: 'Help & Support',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Track current tab index

  late FlutterTts tts;
  late stt.SpeechToText speech;

  @override
  void initState() {
    super.initState();

    // Defer all heavy work until after first frame
    Future.microtask(() async {
      tts = FlutterTts();
      speech = stt.SpeechToText();

      await _initTts();
      await _initSpeechToText();
      await _speakGreeting();
    });
  }

  Future<void> _initTts() async {
    try {
      await tts.setLanguage("en-US");
    } catch (e) {
      developer.log("TTS Init Error: $e", name: 'TTS');
    }
  }

  Future<void> _initSpeechToText() async {
    try {
      bool available = await speech.initialize(
        onError:
            (val) => developer.log('STT Error: $val', name: 'SpeechToText'),
        onStatus:
            (val) => developer.log('STT Status: $val', name: 'SpeechToText'),
      );
      if (!available) {
        developer.log(
          'Speech recognition not available.',
          name: 'SpeechToText',
        );
      }
    } catch (e) {
      developer.log("STT Init Error: $e", name: 'SpeechToText');
    }
  }

  Future<void> _speakGreeting() async {
    if (mounted) {
      try {
        await tts.speak("Welcome to EchoPath. What would you like to do?");
      } catch (e) {
        developer.log("TTS Speak Error: $e", name: 'TTS');
      }
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    tts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: _selectedIndex,
      onTabChanged: _onTabChanged,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home tab content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Welcome to EchoPath!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                FloatingActionButton.extended(
                  heroTag: 'speak_options',
                  onPressed: () async {
                    await tts.speak(
                      "Tabs available: Home, Map, Discover, Downloads, Help and Support. Use voice commands for hands-free navigation.",
                    );
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Speak options'),
                  backgroundColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'voice_map',
                  onPressed: () async {
                    await tts.speak(
                      "Navigating to Map screen for location tracking.",
                    );
                    setState(() {
                      _selectedIndex = 1; // Map tab
                    });
                  },
                  icon: const Icon(Icons.map),
                  label: const Text("Go to Map"),
                  backgroundColor: Colors.green,
                ),
              ],
            ),
          ),
          // Map, Discover, Downloads, Help & Support tabs
          const MapScreen(),
          const TourDiscoveryScreen(),
          const DownloadsScreen(),
          const HelpAndSupportScreen(),
        ],
      ),
    );
  }
}
