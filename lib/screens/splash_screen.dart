import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
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
    // Brief delay to ensure splash is visible for a moment
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = await authProvider.checkLoginStatus();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                isLoggedIn ? const SchedulesScreen() : const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand Logo
            Text(
              'MLT',
              style: TextStyle(
                color: Colors.black,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [
                  Shadow(
                    color: Colors.grey.shade400,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
            ),
            const SizedBox(height: 50),
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
