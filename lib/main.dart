import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/dark_theme.dart';

void main() {
  runApp(const TorrentApp());
}

class TorrentApp extends StatelessWidget {
  const TorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TorrentX',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const HomeScreen(),
    );
  }
}
