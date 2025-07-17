import 'package:flutter/material.dart'; // Import the Material Design library
// Import AppScaffold

class DownloadsScreen extends StatelessWidget {
  // It's good practice for public StatelessWidgets to have a const constructor with a Key.
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Offline Downloads"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          children: const [
            ListTile(
              title: Text(
                "Murchison Falls",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                "Downloaded",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ListTile(
              title: Text(
                "Kasubi Tombs",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                "Downloaded",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
