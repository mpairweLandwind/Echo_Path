# EchoPath - Audio Navigation App

A Flutter application that provides audio-guided navigation and voice commands for enhanced accessibility.

## Setup Instructions

### 1. API Key Configuration

This app requires a Google Maps API key. For security, the API key is stored in a local configuration file.

1. Copy the template file:
   ```bash
   cp android/local.properties.template android/local.properties
   ```

2. Edit `android/local.properties` and replace `your_google_maps_api_key_here` with your actual Google Maps API key.

3. Get your API key from the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)

**Important**: Never commit your actual API key to version control!

### 2. Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Features

- Voice-guided navigation
- Audio commands
- Accessibility-focused design
- Real-time location services
