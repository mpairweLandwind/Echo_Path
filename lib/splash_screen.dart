import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart'; // Import the flutter_tts package
import 'onboarding_screen.dart'; // Replace with your actual home screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key}); // Good practice with const Key

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late FlutterTts tts; // Declared as late, initialized in initState

  @override
  void initState() {
    super.initState();
    tts = FlutterTts(); // Initialize FlutterTts here
    _initTts(); // Initialize TTS settings
    _speakIntro();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        // Essential check before navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingScreen()),
        );
      }
    });
  }

  Future<void> _initTts() async {
    await tts.setLanguage("en-US");
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.5);
  }

  Future<void> _speakIntro() async {
    await tts.speak(
      "Welcome to EchoPath. Your accessible journey begins here. Please wait while we get things ready.",
    );
  }

  @override
  void dispose() {
    tts.stop(); // Stop TTS to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: Colors.blueAccent, size: 100),
            const SizedBox(height: 20),
            const Text(
              "EchoPath",
              style: TextStyle(color: Colors.white, fontSize: 28),
            ),
            const Text(
              "Voice powered tour guide",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.volume_up),
              label: Text("Replay welcome"),
              onPressed: _speakIntro,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
