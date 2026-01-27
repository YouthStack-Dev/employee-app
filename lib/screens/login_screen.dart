import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/glass_container.dart' as glass_container;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tenantController = TextEditingController(text: 'SAM001');
  final _usernameController = TextEditingController(text: 'emp2@emp.com');
  final _passwordController = TextEditingController(text: 'Employee@123');
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request Location and Phone permissions on startup to match RN App.js
    await [
      Permission.location,
      Permission.phone,
    ].request();
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _tenantController.text,
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/schedules');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error ?? 'Login Failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: Stack(
        children: [
          // Subtle background elements to make glass visible (Optional: minimal blobs)
          Positioned(
             top: -50, right: -50,
             child: ImageFiltered(
               imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
               child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                     color: Colors.blue.withOpacity(0.05), // Extremely subtle tint
                     shape: BoxShape.circle,
                  ),
               ),
             )
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: glass_container.GlassContainer(
                opacity: 0.05, // Lower opacity for white-on-white feel
                blur: 20,
                borderRadius: BorderRadius.circular(25),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo Placeholder
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
                      ),
                      child: const Center(
                        child: Icon(Icons.change_history, size: 50, color: Color(0xFF0D47A1)), // Blue logo placeholder
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildTextField(_tenantController, 'Tenant ID'),
                    const SizedBox(height: 16),
                    _buildTextField(_usernameController, 'Username / ID'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _passwordController, 
                      'Password', 
                      isObscure: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Consumer<AuthProvider>(
                      builder: (context, auth, child) {
                        return auth.isLoading
                            ? const CircularProgressIndicator(color: AppColors.primary)
                            : Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D47A1), // Dark Blue
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        elevation: 5,
                                        shadowColor: Colors.blue.withOpacity(0.3),
                                      ),
                                      child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone Login not implemented yet')));
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D47A1), // Dark Blue Text
                                        side: const BorderSide(color: Color(0xFF0D47A1)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        backgroundColor: Colors.transparent,
                                      ),
                                      child: const Text('Login with Phone Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isObscure = false, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)), // Grey text for white bg
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))], // Subtle shadow for depth
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.transparent, // Handle color in Container
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
               suffixIcon: suffixIcon ?? (isObscure 
                  ? const Icon(Icons.visibility_off, color: Colors.grey)
                  : null),
            ),
          ),
        ),
      ],
    );
  }}
