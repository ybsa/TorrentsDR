import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/torrent/torrent_bloc.dart';
import 'bloc/settings/settings_cubit.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/torrent_service.dart';
import 'theme/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Rust bridge
  await TorrentService.initialize();
  
  runApp(const TorrentApp());
}

class TorrentApp extends StatelessWidget {
  const TorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TorrentBloc>(create: (_) => TorrentBloc()),
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()..loadSettings()),
      ],
      child: MaterialApp(
        title: 'Torrent DR',
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
