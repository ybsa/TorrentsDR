# TorrentX - Universal Torrent Downloader

A beautiful, cross-platform torrent download app built with Flutter + Rust.

## Platforms

| Platform | Status |
|----------|--------|
| Windows | ✅ |
| Linux | ✅ |
| Android | ✅ |
| macOS | ✅ |
| iOS | 🔜 |

## Features

- 📁 Download from .torrent files
- 🔗 Download from magnet links
- 🎨 Beautiful dark purple theme
- ⚡ Fast Rust core engine
- 📱 Responsive UI (desktop + mobile)
- ⏸️ Pause/Resume downloads
- 📊 Real-time progress & stats

## Project Structure

```
torrent-app/
├── lib/              # Flutter/Dart UI code
│   ├── main.dart
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── theme/
├── rust/             # Rust core (torrent engine)
│   ├── src/
│   └── Cargo.toml
├── android/          # Android config
├── windows/          # Windows config
├── linux/            # Linux config
└── pubspec.yaml      # Flutter deps
```

## Development

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.0+
- [Rust](https://rustup.rs/) (for core engine)
- Android Studio (for Android builds)
- Visual Studio 2022 with C++ (for Windows builds)

### Run

```bash
# Install dependencies
flutter pub get

# Run on current platform
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d android
flutter run -d linux
```

### Build

```bash
# Android APK
flutter build apk --release

# Windows EXE
flutter build windows --release

# Linux
flutter build linux --release
```

## License

MIT
