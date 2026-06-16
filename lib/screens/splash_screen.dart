import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_theme.dart';
import 'login_screen.dart';
import 'schedules_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    bool isLoggedIn = false;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      isLoggedIn = await authProvider.checkLoginStatus();
    } catch (e) {
      debugPrint('Auth check error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const SchedulesScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.surfaceContainerLowest,
      body: Stack(
        children: [
          // Tonal corner gradients (the "Fluid Executive" depth)
          Positioned(
            top: -100,
            right: -100,
            child: _BlurredGradient(
              size: 320,
              color: FxColors.primary.withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _BlurredGradient(
              size: 280,
              color: FxColors.secondary.withOpacity(0.05),
            ),
          ),

          // Main content
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(),
                // Brand anchor — MLT logotype
                Text('MLT', style: FxText.displayLg()),
                const SizedBox(height: 12),
                Text(
                  'MOBILITY REIMAGINED',
                  style: FxText.labelXs(color: FxColors.onSurfaceVariant)
                      .copyWith(letterSpacing: 3.2),
                ),
                const Spacer(),
                // Loading indicator (concentric — branded primary on track)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FxColors.surfaceContainerHigh,
                            width: 3,
                          ),
                        ),
                      ),
                      const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(FxColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Initializing Secure Session', style: FxText.labelSm()),
                const SizedBox(height: 64),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _BlurredGradient extends StatelessWidget {
  final double size;
  final Color color;
  const _BlurredGradient({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
