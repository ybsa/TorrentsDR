# KujaPirates - Universal Torrent Downloader

A beautiful, high-performance, cross-platform torrent download application built with **Flutter** and **Rust**.

![KujaPirates Banner](https://via.placeholder.com/1200x600.png?text=KujaPirates+Preview)

## 🚀 Key Features

*   **Unified Backend**: Powered by [librqbit](https://github.com/ikatson/rqbit), a fast and reliable BitTorrent library written in Rust.
*   **Cross-Platform**: Runs smoothly on **Windows**, **Android**, and **Linux**.
*   **Modern UI**: Sleek, dark-themed responsive interface designed with Flutter.
*   **Magnet Link Support**: Seamlessly handle magnet links with automatic metadata fetching.
*   **Torrent Files**: Open and download from `.torrent` files.
*   **Universal Android**: Supports both modern (64-bit) and older (32-bit) devices.

## 🛠️ Architecture

This project uses `flutter_rust_bridge` to connect the performant Rust backend with the flexible Flutter frontend.

*   **Frontend**: Flutter (Dart) - Handles UI, state management (Bloc), and platform integrations.
*   **Backend**: Rust - Handles all BitTorrent networking, file I/O, and session management via `librqbit`.

## 📦 platforms

| Platform | Status | Support |
|----------|--------|---------|
| **Windows** | ✅ Stable | Fully Supported (x64) |
| **Android** | ✅ Stable | Universal (arm64, v7a, x86_64) |
| **Linux** | ✅ Stable | Fully Supported |
| **macOS** | 🚧 Beta | Experimental |
| **iOS** | 🔜 Planned | Coming Soon |

## 💻 Development Setup

### Prerequisites

*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0+)
*   [Rust Toolchain](https://rustup.rs/) (Stable)
*   [LLVM/Clang](https://releases.llvm.org/download.html) (Required for `flutter_rust_bridge` codegen)
*   **Windows**: Visual Studio 2022 with C++ Desktop Development workload.
*   **Android**: Android Studio & NDK.

### Installation & Running

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/YourUsername/KujaPirates.git
    cd KujaPirates
    ```

2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run Code Generator (Important):**
    This generates the dart-rust bridge code.
    ```bash
    flutter_rust_bridge_codegen generate
    ```

4.  **Run the App:**
    ```bash
    # Run on Windows
    flutter run -d windows

    # Run on Android
    flutter run -d android
    ```

## 🏗️ Building for Release

### Windows
```bash
flutter build windows --release
```
The executable will be in `build/windows/runner/Release/`.

### Android
```bash
flutter build apk --release
```
The Universal APK is located in `releases/KujaPirates.apk`.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
