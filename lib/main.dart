import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/torrent/torrent_bloc.dart';
import 'bloc/settings/settings_cubit.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/torrent_service.dart';
import 'theme/dark_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't await here, let the app start immediately
  runApp(const TorrentApp());
}

class TorrentApp extends StatefulWidget {
  const TorrentApp({super.key});

  @override
  State<TorrentApp> createState() => _TorrentAppState();
}

class _TorrentAppState extends State<TorrentApp> {
  // Initialize Rust bridge asynchronously
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await TorrentService.initialize();
      print("Rust bridge initialized successfully");
    } catch (e, stack) {
      print("Failed to initialize Rust bridge: $e\n$stack");
      // You might want to show a global error dialog here later
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TorrentBloc>(create: (_) => TorrentBloc()),
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()..loadSettings()),
      ],
      child: MaterialApp(
        title: 'KujaPirates',
        debugShowCheckedModeBanner: false,
        theme: darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
