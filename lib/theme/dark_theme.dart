import 'package:flutter/material.dart';

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  
  // Color scheme - Purple accent
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF9C27B0),       // Purple
    secondary: const Color(0xFFE040FB),      // Light purple
    surface: const Color(0xFF1E1E2E),        // Dark surface
    background: const Color(0xFF0F0F1A),     // Darker background
    error: const Color(0xFFCF6679),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    onBackground: Colors.white,
  ),
  
  // Scaffold
  scaffoldBackgroundColor: const Color(0xFF0F0F1A),
  
  // App Bar
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E2E),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
  ),
  
  // Cards
  cardTheme: CardTheme(
    color: const Color(0xFF1E1E2E),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  
  // Buttons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF9C27B0),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  
  // FAB
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF9C27B0),
    foregroundColor: Colors.white,
  ),
  
  // Text
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Colors.white70,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      color: Colors.white54,
    ),
  ),
  
  // Input
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2A2A3E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  
  // Divider
  dividerTheme: const DividerThemeData(
    color: Color(0xFF2A2A3E),
    thickness: 1,
  ),
  
  // Progress Indicator
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFF9C27B0),
    linearTrackColor: Color(0xFF2A2A3E),
  ),
);
