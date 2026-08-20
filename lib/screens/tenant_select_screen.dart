import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';

class TenantSelectScreen extends StatefulWidget {
  const TenantSelectScreen({super.key});

  @override
  State<TenantSelectScreen> createState() => _TenantSelectScreenState();
}

class _TenantSelectScreenState extends State<TenantSelectScreen> {
  static const _royalBlue = FxColors.primary;
  static const _navy = FxColors.onSurface;
  static const _secondary = FxColors.onSurfaceVariant;
  static const _pageBg = FxColors.background;

  List<Map<String, dynamic>> _tenants = [];
  String? _selectingTenantId;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _tenants = List.of(auth.availableTenants ?? []);
  }

  Future<void> _selectTenant(Map<String, dynamic> tenant) async {
    final id = tenant['tenant_id']?.toString();
    if (id == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _selectingTenantId = id);

    final ok = await auth.selectOtpTenant(id);
    if (!mounted) return;
    setState(() => _selectingTenantId = null);

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/schedules', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to select organization'),
          backgroundColor: FxColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _tenants.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: _royalBlue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _introCard(),
                          const SizedBox(height: 20),
                          _tenantsCard(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_rounded, size: 24, color: _navy),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Select Organization',
            style: FxText.headlineLg(),
          ),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FxColors.primary.withValues(alpha: 0.07),
            FxColors.primaryContainer.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FxColors.surfaceContainerHigh),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: FxColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_rounded, size: 26, color: _royalBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your organization',
                  style: FxText.headlineMd().copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your account is linked to multiple organizations. Pick one to continue.',
                  style: FxText.bodyLg(color: _secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tenantsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FxColors.surfaceContainerHigh),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organizations',
            style: FxText.headlineMd().copyWith(fontSize: 19),
          ),
          const SizedBox(height: 8),
          ..._tenants.asMap().entries.map((entry) {
            final tile = _tenantTile(entry.value);
            if (entry.key == 0) return tile;
            return Column(
              children: [
                const Divider(color: FxColors.surfaceContainerHigh, height: 1, thickness: 1),
                tile,
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tenantTile(Map<String, dynamic> tenant) {
    final id = tenant['tenant_id']?.toString() ?? '';
    final name = tenant['name']?.toString() ?? id;
    final isSelecting = _selectingTenantId == id;

    return InkWell(
      onTap: isSelecting ? null : () => _selectTenant(tenant),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: FxColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.apartment_rounded, size: 20, color: _royalBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: FxText.headlineMd().copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    id,
                    style: FxText.body(color: _secondary).copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isSelecting)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _royalBlue),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 22, color: _secondary),
          ],
        ),
      ),
    );
  }
}
