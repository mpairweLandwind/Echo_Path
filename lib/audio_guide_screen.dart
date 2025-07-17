import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/location_service.dart';
import '../models/landmark.dart';

class AudioGuideScreen extends StatefulWidget {
  const AudioGuideScreen({super.key});

  @override
  State<AudioGuideScreen> createState() => _AudioGuideScreenState();
}

class _AudioGuideScreenState extends State<AudioGuideScreen> {
  late AudioPlayer audioPlayer;
  late AudioPlayer ambientPlayer;
  final LocationService _locationService = LocationService();

  bool isPlaying = false;
  bool isAmbientPlaying = false;
  String currentTrackTitle = "Murchison Falls Tour Audio";
  Landmark? currentLandmark;

  // Audio URLs
  final String audioUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  final String ambientUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    ambientPlayer = AudioPlayer();

    audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });

    audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    });

    ambientPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isAmbientPlaying = state == PlayerState.playing;
        });
      }
    });

    // Initialize location service and get current landmark
    _initializeLocationService();

    // TTS instructions on open
    Future.microtask(() async {
      await _speakInstructions();
    });
  }

  Future<void> _initializeLocationService() async {
    await _locationService.initialize();
    final nearbyLandmarks = _locationService.nearbyLandmarks;
    if (nearbyLandmarks.isNotEmpty) {
      setState(() {
        currentLandmark = nearbyLandmarks.first;
        currentTrackTitle = "${currentLandmark!.name} Tour Audio";
      });
    }
  }

  Future<void> _playAudio() async {
    if (!isPlaying) {
      await audioPlayer.play(UrlSource(audioUrl));
      // Start ambient sound if available
      if (currentLandmark?.ambientSound != null && !isAmbientPlaying) {
        await _playAmbientSound();
      }
    }
  }

  Future<void> _pauseAudio() async {
    if (isPlaying) {
      await audioPlayer.pause();
      await ambientPlayer.pause();
    }
  }

  Future<void> _stopAudio() async {
    await audioPlayer.stop();
    await ambientPlayer.stop();
    if (mounted) {
      setState(() {
        isPlaying = false;
        isAmbientPlaying = false;
      });
    }
  }

  Future<void> _playAmbientSound() async {
    if (!isAmbientPlaying) {
      await ambientPlayer.play(UrlSource(ambientUrl));
      // Set ambient volume lower than main audio
      await ambientPlayer.setVolume(0.3);
    }
  }

  Future<void> _toggleAmbientSound() async {
    if (isAmbientPlaying) {
      await ambientPlayer.pause();
    } else {
      await _playAmbientSound();
    }
  }

  Future<void> _speakInstructions() async {
    String instructions =
        "You are on the ${currentLandmark?.name ?? 'Murchison Falls'} audio tour. ";
    instructions +=
        "Use the play button to start narration, pause to stop, and stop to end playback. ";
    instructions +=
        "Ambient sounds will play in the background to enhance your experience. ";
    instructions +=
        "Use voice commands like 'where am I' or 'nearby attractions' for hands-free navigation.";

    await FlutterTts().speak(instructions);
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    ambientPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Murchison Falls Tour"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.place, color: Colors.white, size: 100),
            const SizedBox(height: 20),
            Text(
              isPlaying
                  ? "Playing: $currentTrackTitle"
                  : "Ready to Play: $currentTrackTitle",
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 80,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      _pauseAudio();
                    } else {
                      _playAudio();
                    }
                  },
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(
                    Icons.stop_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                  onPressed: _stopAudio,
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.volume_up),
                  label: Text("Replay instructions"),
                  onPressed: _speakInstructions,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: Icon(
                    isAmbientPlaying ? Icons.volume_off : Icons.volume_up,
                  ),
                  label: Text(
                    isAmbientPlaying ? "Stop Ambient" : "Start Ambient",
                  ),
                  onPressed: _toggleAmbientSound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isAmbientPlaying ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (currentLandmark != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha((255 * 0.3).round())),
                ),
                child: Column(
                  children: [
                    Text(
                      currentLandmark!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentLandmark!.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
