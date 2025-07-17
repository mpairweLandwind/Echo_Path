import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'login_screen.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  late FlutterTts tts;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    tts = FlutterTts();

    // Initialize TTS and then speak tutorial
    Future.microtask(() async {
      await _initTts();
      await _speakTutorial();
    });

    // Fallback auto navigation after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (!_navigated && mounted) {
        _goToLogin();
      }
    });
  }

  void _goToLogin() {
    if (_navigated) return;
    _navigated = true;
    tts.speak("Navigating to login screen. Please wait.");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  Future<void> _initTts() async {
    await tts.setLanguage("en-US");
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.5); // Slow down for accessibility
  }

  Future<void> _speakTutorial() async {
    await tts.speak(
      "Tap anywhere to continue. "
      "This app helps you discover nearby places through voice. "
      "Use commands like, what's near me, or download tours for offline use.",
    );
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToLogin,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 180, 87, 87),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome to EchoPath 👋",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 20),
              const Text(
                "Your accessible tour guide. Tap anywhere or press Continue to proceed.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _goToLogin,
                child: const Text("Continue"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.volume_up),
                label: Text("Replay onboarding instructions"),
                onPressed: _speakTutorial,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
