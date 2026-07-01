import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/fx_widgets.dart';

/// Three-step employee password reset:
///   1. request OTP   POST /api/v1/auth/employee/forgot-password {tenant_id, email}
///   2. verify OTP    POST /api/v1/auth/employee/forgot-password/verify {tenant_id, email, otp}
///   3. set password  PUT  /api/v1/auth/employee/password {password_set_token, new_password, confirm_password}
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialTenantId;
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialTenantId, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Matches the backend policy:
  // ^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$
  static final RegExp _passwordPattern =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

  int _step = 0; // 0 request, 1 verify, 2 set
  final _tenantController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _newPwVisible = false;
  bool _confirmPwVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTenantId != null) _tenantController.text = widget.initialTenantId!;
    if (widget.initialEmail != null) _emailController.text = widget.initialEmail!;
    _newPwController.addListener(_onChanged);
    _confirmPwController.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPwController.removeListener(_onChanged);
    _confirmPwController.removeListener(_onChanged);
    _tenantController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? FxColors.error : FxColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());
  bool get _newPwValid => _passwordPattern.hasMatch(_newPwController.text);
  bool get _confirmValid =>
      _confirmPwController.text.isNotEmpty && _confirmPwController.text == _newPwController.text;

  Future<void> _requestOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenant = _tenantController.text.trim();
    final email = _emailController.text.trim();
    if (tenant.isEmpty) return _toast('Enter your Tenant ID');
    if (!_emailValid) return _toast('Enter a valid email address');
    final ok = await auth.forgotPassword(tenant, email);
    if (!mounted) return;
    if (ok) {
      setState(() => _step = 1);
      _toast('If your email is registered, an OTP has been sent.', error: false);
    } else {
      _toast(auth.error ?? 'Could not send OTP');
    }
  }

  Future<void> _verifyOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final otp = _otpController.text.trim();
    if (otp.length != 6) return _toast('Enter the 6-digit OTP');
    final ok = await auth.verifyForgotPassword(
      _tenantController.text.trim(),
      _emailController.text.trim(),
      otp,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _step = 2);
    } else {
      _toast(auth.error ?? 'Invalid OTP');
    }
  }

  Future<void> _setPassword() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!_newPwValid) {
      return _toast('Password must meet all the requirements below');
    }
    if (!_confirmValid) return _toast('Passwords do not match');
    final ok = await auth.setNewPassword(_newPwController.text, _confirmPwController.text);
    if (!mounted) return;
    if (ok) {
      _toast('Password updated. Welcome back!', error: false);
      Navigator.pushNamedAndRemoveUntil(context, '/schedules', (route) => false);
    } else {
      _toast(auth.error ?? 'Could not set password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepper(),
                    const SizedBox(height: 20),
                    FxCard(
                      padding: const EdgeInsets.all(20),
                      child: _stepBody(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    const titles = ['Reset password', 'Enter OTP', 'New password'];
    const subtitles = [
      'We\'ll send a one-time code to your email',
      'Check your email for the 6-digit code',
      'Choose a strong new password',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () {
              if (_step == 0) {
                Navigator.pop(context);
              } else {
                setState(() => _step -= 1);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[_step], style: FxText.headlineSm(color: FxColors.primary)),
                Text(subtitles[_step], style: FxText.bodySm()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 5,
            decoration: BoxDecoration(
              gradient: active ? FxGradients.indigo : null,
              color: active ? null : FxColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _requestStep();
      case 1:
        return _verifyStep();
      default:
        return _setStep();
    }
  }

  Widget _requestStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxTextField(
          controller: _tenantController,
          label: 'Tenant ID',
          hint: 'Tenant ID',
          prefixIcon: Icons.domain_rounded,
        ),
        const SizedBox(height: 16),
        FxTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Email',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: 'Send OTP',
            trailingIcon: Icons.arrow_forward_rounded,
            loading: auth.isLoading,
            onPressed: auth.isLoading ? null : _requestOtp,
          ),
        ),
      ],
    );
  }

  Widget _verifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Code sent to ${_emailController.text.trim()}', style: FxText.bodySm()),
        const SizedBox(height: 14),
        FxTextField(
          controller: _otpController,
          label: 'One-Time Password',
          hint: '6-digit code',
          prefixIcon: Icons.pin_rounded,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: 'Verify',
            trailingIcon: Icons.arrow_forward_rounded,
            loading: auth.isLoading,
            onPressed: auth.isLoading ? null : _verifyOtp,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => _requestOtp(),
            child: Text('Resend code', style: FxText.titleSm(color: FxColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _setStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxTextField(
          controller: _newPwController,
          label: 'New password',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: !_newPwVisible,
          suffixIcon: _newPwVisible ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () => setState(() => _newPwVisible = !_newPwVisible),
        ),
        const SizedBox(height: 12),
        _RequirementsChecklist(password: _newPwController.text),
        const SizedBox(height: 16),
        FxTextField(
          controller: _confirmPwController,
          label: 'Confirm password',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscure: !_confirmPwVisible,
          suffixIcon: _confirmPwVisible ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () => setState(() => _confirmPwVisible = !_confirmPwVisible),
          errorText: _confirmPwController.text.isNotEmpty && !_confirmValid ? 'Passwords do not match' : null,
        ),
        const SizedBox(height: 24),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => FxPrimaryButton(
            label: 'Set password & continue',
            trailingIcon: Icons.check_rounded,
            loading: auth.isLoading,
            onPressed: (auth.isLoading || !_newPwValid || !_confirmValid) ? null : _setPassword,
          ),
        ),
      ],
    );
  }
}

class _RequirementsChecklist extends StatelessWidget {
  final String password;
  const _RequirementsChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = <String, bool>{
      'At least 8 characters': password.length >= 8,
      'An uppercase letter': RegExp(r'[A-Z]').hasMatch(password),
      'A lowercase letter': RegExp(r'[a-z]').hasMatch(password),
      'A number': RegExp(r'\d').hasMatch(password),
      'A special character (@\$!%*?&)': RegExp(r'[@$!%*?&]').hasMatch(password),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rules.entries.map((e) {
          final met = e.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: met ? const Color(0xFF00B894) : FxColors.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  e.key,
                  style: FxText.bodySm(
                    color: met ? FxColors.onSurface : FxColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
