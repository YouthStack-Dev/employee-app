import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../constants/app_theme.dart';
import '../widgets/fx_widgets.dart';
import '../services/tracking_service.dart';
import 'forgot_password_screen.dart';
import 'tenant_select_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tenantController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  String? _tenantError;
  String? _usernameError;
  String? _passwordError;

  // OTP toggle state
  bool _showPasswordLogin = false;
  bool _showPhoneOtp = false;
  final _otpEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpCodeController = TextEditingController();
  bool _isOtpSent = false;

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
    _otpEmailController.dispose();
    _phoneController.dispose();
    _otpCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final tenantId = _tenantController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _tenantError = tenantId.isEmpty ? 'Please enter your Tenant ID' : null;
      _usernameError = username.isEmpty ? 'Please enter your email or username' : null;
      _passwordError = password.isEmpty ? 'Please enter your password' : null;
    });

    if (_tenantError != null || _usernameError != null || _passwordError != null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(tenantId, username, password);

    if (!mounted) return;

    if (success) {
      TrackingService.logEvent('email_login_success');
      Navigator.pushReplacementNamed(context, '/schedules');
    } else {
      _toast(auth.error ?? 'Login failed', error: true);
    }
  }

  Future<void> _handleSendOtp({required bool isEmail}) async {
    final username = isEmail ? _otpEmailController.text.trim() : _phoneController.text.trim();
    if (username.isEmpty) {
      _toast(isEmail ? 'Please enter your email' : 'Please enter your phone number', error: true);
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.sendOtp(username);

    if (!mounted) return;

    if (result) {
      setState(() => _isOtpSent = true);
      _toast('OTP sent successfully');
    } else {
      _toast(auth.error ?? 'Failed to send OTP', error: true);
    }
  }

  Future<void> _handleVerifyOtp({required bool isEmail}) async {
    final username = isEmail ? _otpEmailController.text.trim() : _phoneController.text.trim();
    final otp = _otpCodeController.text.trim();

    if (otp.isEmpty) {
      _toast('Please enter the OTP', error: true);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(username, otp);

    if (!mounted) return;

    if (success) {
      TrackingService.logEvent(isEmail ? 'email_otp_login_success' : 'mobile_login_success');
      Navigator.pushReplacementNamed(context, '/schedules');
    } else if (auth.needsTenantSelection) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TenantSelectScreen()),
      );
    } else {
      _toast(auth.error ?? 'Invalid OTP', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(gradient: FxGradients.indigoFooter),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _BrandHeader(),
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FxCard(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(28),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _showPasswordLogin || _showPhoneOtp
                              ? (_showPasswordLogin
                                  ? KeyedSubtree(key: const ValueKey('password'), child: _buildPasswordForm())
                                  : KeyedSubtree(key: const ValueKey('phone_otp'), child: _buildOtpForm()))
                              : KeyedSubtree(key: const ValueKey('email_otp'), child: _buildOtpForm()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _showPasswordLogin = false;
                _showPhoneOtp = false;
                _isOtpSent = false;
                _otpCodeController.clear();
              }),
              icon: const Icon(Icons.arrow_back_rounded, color: FxColors.onSurface),
              tooltip: 'Go back',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 8),
            Text('Login to fleet account', style: FxText.headlineMd()),
          ],
        ),
        const SizedBox(height: 24),
        FxTextField(
          controller: _tenantController,
          label: 'Tenant ID',
          hint: 'Your organization ID',
          prefixIcon: Icons.domain_rounded,
          errorText: _tenantError,
          onChanged: (_) {
            if (_tenantError != null) setState(() => _tenantError = null);
          },
        ),
        const SizedBox(height: 16),
        FxTextField(
          controller: _usernameController,
          label: 'Email / Username',
          hint: 'your.email@company.com',
          prefixIcon: Icons.badge_outlined,
          keyboardType: TextInputType.emailAddress,
          errorText: _usernameError,
          onChanged: (_) {
            if (_usernameError != null) setState(() => _usernameError = null);
          },
        ),
        const SizedBox(height: 16),
        FxTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          obscure: !_isPasswordVisible,
          errorText: _passwordError,
          onChanged: (_) {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForgotPasswordScreen(
                  initialTenantId: _tenantController.text.trim().isEmpty
                      ? null
                      : _tenantController.text.trim(),
                  initialEmail: _usernameController.text.trim().contains('@')
                      ? _usernameController.text.trim()
                      : null,
                ),
              ),
            ),
            child: Text('Forgot password?', style: FxText.titleSm(color: FxColors.primary)),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: 'Login',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _handleLogin,
            loading: auth.isLoading,
          ),
        ),
        const SizedBox(height: 24),
        _buildDivider(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              TrackingService.logEvent('email_otp_selected');
              setState(() {
                _showPasswordLogin = false;
                _showPhoneOtp = false;
                _isOtpSent = false;
                _otpCodeController.clear();
              });
            },
            icon: const Icon(Icons.email_outlined, color: FxColors.primary),
            label: Text('Login with Email OTP',
                style: FxText.titleSm(color: FxColors.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: FxColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              TrackingService.logEvent('phone_otp_selected');
              setState(() {
                _showPhoneOtp = true;
                _showPasswordLogin = false;
                _isOtpSent = false;
                _otpCodeController.clear();
              });
            },
            icon: const Icon(Icons.phone_rounded, color: FxColors.primary),
            label: Text('Login with Phone Number',
                style: FxText.titleSm(color: FxColors.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: FxColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpForm() {
    final isEmail = !_showPasswordLogin && !_showPhoneOtp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEmail)
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _showPasswordLogin = false;
                  _showPhoneOtp = false;
                  _isOtpSent = false;
                  _otpCodeController.clear();
                }),
                icon: const Icon(Icons.arrow_back_rounded, color: FxColors.onSurface),
                tooltip: 'Go back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              const SizedBox(width: 8),
            ],
          ),
        if (!isEmail) ...[
          Text('Phone OTP Login', style: FxText.headlineSm()),
          const SizedBox(height: 24),
        ],
        FxTextField(
          controller: isEmail ? _otpEmailController : _phoneController,
          label: isEmail ? 'Email Address' : 'Phone Number',
          hint: isEmail ? 'your.email@company.com' : '+91 9876543210',
          prefixIcon: isEmail ? Icons.email_outlined : Icons.phone_rounded,
          keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.phone,
          readOnly: _isOtpSent,
        ),
        if (_isOtpSent) ...[
          const SizedBox(height: 16),
          FxTextField(
            controller: _otpCodeController,
            label: 'One-Time Password',
            hint: 'Enter 6-digit OTP',
            prefixIcon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 24),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: _isOtpSent ? 'Verify & Login' : 'Send OTP',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: _isOtpSent
                ? () => _handleVerifyOtp(isEmail: isEmail)
                : () => _handleSendOtp(isEmail: isEmail),
            loading: auth.isLoading,
          ),
        ),
        if (_isOtpSent) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isOtpSent = false;
                  _otpCodeController.clear();
                });
                _handleSendOtp(isEmail: isEmail);
              },
              child: Text('Resend OTP', style: FxText.titleSm(color: FxColors.primary)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildDivider(),
        const SizedBox(height: 16),
        if (isEmail) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                TrackingService.logEvent('phone_otp_selected');
                setState(() {
                  _showPhoneOtp = true;
                  _showPasswordLogin = false;
                  _isOtpSent = false;
                  _otpCodeController.clear();
                });
              },
              icon: const Icon(Icons.phone_rounded, color: FxColors.primary),
              label: Text('Login with Phone Number',
                  style: FxText.titleSm(color: FxColors.primary)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: FxColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() {
              _showPasswordLogin = true;
              _showPhoneOtp = false;
              _isOtpSent = false;
              _otpCodeController.clear();
            }),
            icon: Icon(isEmail ? Icons.domain_rounded : Icons.email_outlined,
                color: FxColors.primary),
            label: Text(
              isEmail ? 'Login with Tenant ID & Password' : 'Back to Email OTP',
              style: FxText.titleSm(color: FxColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: FxColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (!isEmail) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _showPasswordLogin = true;
                _showPhoneOtp = false;
                _isOtpSent = false;
                _otpCodeController.clear();
              }),
              icon: const Icon(Icons.domain_rounded, color: FxColors.primary),
              label: Text('Login with Tenant ID & Password',
                  style: FxText.titleSm(color: FxColors.primary)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: FxColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: _Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: FxText.body(color: FxColors.onSurfaceVariant)),
        ),
        const Expanded(child: _Divider()),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          const Positioned.fill(
            child: Opacity(opacity: 0.35, child: _DotGrid()),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [FxColors.background.withOpacity(0.0), FxColors.background],
                ),
              ),
            ),
          ),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
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
