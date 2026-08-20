import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';

class TenantSwitchScreen extends StatefulWidget {
  const TenantSwitchScreen({super.key});

  @override
  State<TenantSwitchScreen> createState() => _TenantSwitchScreenState();
}

class _TenantSwitchScreenState extends State<TenantSwitchScreen> {
  static const _royalBlue = FxColors.primary;
  static const _navy = FxColors.onSurface;
  static const _secondary = FxColors.onSurfaceVariant;
  static const _pageBg = FxColors.background;

  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String? _switchingTenantId;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenants = await auth.getSwitchableTenants();
    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _isLoading = false;
    });
  }

  Future<void> _switchTenant(Map<String, dynamic> tenant) async {
    final id = tenant['tenant_id']?.toString();
    if (id == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _switchingTenantId = id);

    final ok = await auth.switchTenant(id);
    if (!mounted) return;
    setState(() => _switchingTenantId = null);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to switch organization'),
          backgroundColor: FxColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _royalBlue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _currentOrgCard(user?.tenantName, user?.tenantId),
                          const SizedBox(height: 20),
                          if (_tenants.isNotEmpty)
                            _tenantsCard()
                          else
                            _emptyState(),
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
            'Switch Organization',
            style: FxText.headlineLg(),
          ),
        ],
      ),
    );
  }

  Widget _currentOrgCard(String? tenantName, String? tenantId) {
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
            child: const Icon(Icons.domain_rounded, size: 26, color: _royalBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenantName ?? 'Current Organization',
                  style: FxText.headlineMd().copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  tenantId ?? '',
                  style: FxText.bodyLg(color: _secondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Current',
              style: FxText.label(color: _royalBlue).copyWith(fontSize: 12),
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
            'Available organizations',
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
    final isSwitching = _switchingTenantId == id;

    return InkWell(
      onTap: isSwitching ? null : () => _switchTenant(tenant),
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
            if (isSwitching)
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

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.business_outlined, size: 48, color: _secondary),
            const SizedBox(height: 12),
            Text(
              'No other organizations available',
              style: FxText.headlineMd().copyWith(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'You are enrolled in only this organization.',
              style: FxText.bodyLg(color: _secondary),
            ),
          ],
        ),
      ),
    );
  }
}
