import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../constants/app_theme.dart';
import '../widgets/fx_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tenantController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPhoneLogin = false;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.location, Permission.phone].request();
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _tenantController.text,
      _usernameController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/schedules');
    } else {
      _toast(authProvider.error ?? 'Login failed', error: true);
    }
  }

  Future<void> _handleSendOtp() async {
    if (_phoneController.text.isEmpty) {
      _toast('Please enter phone number');
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.sendOtp(_phoneController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _isOtpSent = true);
      _toast('OTP Sent');
    } else {
      _toast(auth.error ?? 'Failed to send OTP', error: true);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.isEmpty) {
      _toast('Please enter OTP');
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.verifyOtp(_phoneController.text, _otpController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/schedules');
    } else {
      _toast(auth.error ?? 'Invalid OTP', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? FxColors.error : FxColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Decorative geometric header (dot grid + fade)
              _BrandHeader(),
              // Card body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Transform.translate(
                    offset: const Offset(0, -40),
                    child: FxCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome Back', style: FxText.headlineMd()),
                          const SizedBox(height: 6),
                          Text(
                            'Secure access to your enterprise mobility suite',
                            style: FxText.body(color: FxColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          if (_isPhoneLogin)
                            _buildPhoneForm()
                          else
                            _buildEmailForm(),
                          const SizedBox(height: 24),
                          const _Divider(),
                          const SizedBox(height: 20),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: FxText.bodySm(),
                                children: [
                                  const TextSpan(text: "Don't have an account?  "),
                                  TextSpan(
                                    text: 'Contact HR',
                                    style: FxText.titleSm(color: FxColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: FxColors.surfaceContainerLow,
                                borderRadius: FxRadii.pill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: FxColors.emeraldDot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SYSTEM STATUS: OPERATIONAL',
                                    style: FxText.labelSm(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Footer strip
              Container(
                height: 4,
                decoration: const BoxDecoration(gradient: FxGradients.indigoFooter),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        FxTextField(
          controller: _tenantController,
          label: 'Tenant ID',
          hint: 'e.g. CORP_GLOBAL',
          prefixIcon: Icons.domain_rounded,
        ),
        const SizedBox(height: 16),
        FxTextField(
          controller: _usernameController,
          label: 'Employee ID / Email',
          hint: 'ID or business email',
          prefixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        FxTextField(
          controller: _passwordController,
          label: 'Password',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          obscure: !_isPasswordVisible,
        ),
        const SizedBox(height: 24),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: 'Login',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _handleLogin,
            loading: auth.isLoading,
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => setState(() {
            _isPhoneLogin = true;
            _isOtpSent = false;
          }),
          child: Text(
            'Use phone number instead',
            style: FxText.titleSm(color: FxColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
        FxTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: '+91 9xxxx xxxxx',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        if (_isOtpSent) ...[
          const SizedBox(height: 16),
          FxTextField(
            controller: _otpController,
            label: 'One-Time Password',
            hint: '6-digit code',
            prefixIcon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 24),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: _isOtpSent ? 'Verify & Login' : 'Send OTP',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _isOtpSent ? _handleVerifyOtp : _handleSendOtp,
            loading: auth.isLoading,
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => setState(() => _isPhoneLogin = false),
          child: Text('Back to email login', style: FxText.titleSm(color: FxColors.primary)),
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLowest,
        image: const DecorationImage(
          alignment: Alignment.center,
          image: AssetImage('assets/images/logo.png'),
          opacity: 0.0, // placeholder so the asset path is referenced
        ),
      ),
      child: Stack(
        children: [
          // Dot-grid geometric pattern via CustomPaint
          const Positioned.fill(
            child: Opacity(opacity: 0.35, child: _DotGrid()),
          ),
          // Soft fade to background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, FxColors.background],
                ),
              ),
            ),
          ),
          // Brand anchor
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: FxColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F4C40DF),
                        blurRadius: 30,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: FxColors.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text('MLT Mobility', style: FxText.headlineLg()),
                const SizedBox(height: 4),
                Text('CORPORATE TRANSPORT PORTAL',
                    style: FxText.labelXs(color: FxColors.onSurfaceVariant)
                        .copyWith(letterSpacing: 2.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridPainter());
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = FxColors.primary.withOpacity(0.25);
    const step = 32.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: FxColors.outlineVariant.withOpacity(0.2));
}
