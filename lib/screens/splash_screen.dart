import 'package:flutter/material.dart';
import '../services/torrent_service.dart';

/// Splash screen shown while app initializes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Start initialization
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for at least 2.5 seconds AND for the Rust backend to be ready
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 2500)),
        // We assume this service is safe to call multiple times (memoized)
        // Accessing the service dynamically or via import
        _initBackend(),
      ]);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _initBackend() async {
     // Lazy way to avoid importing if not already, but we should import it.
     // Assuming import 'services/torrent_service.dart' is at the top.
     // We need to add the import if it's missing.
     // For this replace block, I'll rely on the existing imports or add it.
     // Ideally I'd use the fully qualified name if uncertain, but I see the file context.
     // Let's assume the user has the import or I'll add it in a separate step if needed.
     // Actually, I can't assume. I should check imports. The file view showed imports.
     // It didn't import torrent_service.dart. I need to add that import.
     await TorrentService.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               _buildAnimation(),
               if (_hasError) ...[
                 const SizedBox(height: 32),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 32),
                   child: Text(
                     "Initialization Failed",
                     style: TextStyle(color: Colors.red[300], fontSize: 16, fontWeight: FontWeight.bold),
                     textAlign: TextAlign.center,
                   ),
                 ),
                 const SizedBox(height: 8),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 32),
                   child: Text(
                     _errorMessage,
                     style: const TextStyle(color: Colors.white70, fontSize: 12),
                     textAlign: TextAlign.center,
                   ),
                 ),
                 const SizedBox(height: 16),
                 ElevatedButton(
                   onPressed: () {
                     setState(() {
                       _hasError = false;
                       _errorMessage = '';
                     });
                     _initializeApp();
                   },
                   child: const Text("Retry"),
                 )
               ] else ...[
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
               ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icons/icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.bolt,
                        size: 60, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Torrent DR',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '— EVLF ERIS LAB —',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
