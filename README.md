# LockUnlock

A Flutter-based mobile application designed to manage device security and app usage monitoring.

## Features

- Device lock/unlock functionality
- App usage monitoring and statistics
- Detailed app event tracking
- Cross-platform support (Android, Web, Windows, macOS)

## Technical Stack

- **Framework**: Flutter
- **Platforms**: Android, Web, Windows, macOS.
- **Architecture**: Clean architecture with service-based implementation

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── models/
│   └── app_usage.dart     # Data models for app usage
├── screens/
│   ├── app_events_screen.dart  # App events display
│   └── app_usage_screen.dart   # App usage statistics
└── services/
    └── app_usage_service.dart  # App usage monitoring service
```

## Getting Started

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Requirements

- Flutter SDK
- Dart SDK
- Platform-specific development tools (Android Studio, Xcode, etc.)






