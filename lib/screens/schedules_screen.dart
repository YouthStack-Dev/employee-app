import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../models/booking_model.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/time_format_provider.dart';
import '../services/review_service.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import '../utils/time_format.dart';
import 'announcements_screen.dart';
import 'notification_history_screen.dart';
import 'booking_details_screen.dart';
import 'chat_screen.dart';
import 'create_booking_screen.dart';
import 'edit_booking_screen.dart';
import 'my_addresses_screen.dart';
import 'nodal_scan_screen.dart';
import 'personal_details_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'sos_details_screen.dart';
import 'sos_history_screen.dart';
import 'tenant_switch_screen.dart';
import 'track_driver_screen.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  int _bottomIndex = 0; // 0 bookings (default), 1 profile
  int _segmentIndex = 0; // 0 upcoming, 1 past
  bool _isActiveCardExpanded = true;
  DateTime _selectedHistoryDate = DateTime.now();
  List<Map<String, dynamic>> _switchableTenants = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBookings();
      _loadSwitchableTenants();
    });
  }

  Future<void> _loadSwitchableTenants() async {
    final tenants = await Provider.of<AuthProvider>(context, listen: false)
        .getSwitchableTenants();
    if (!mounted) return;
    if (tenants.length != _switchableTenants.length) {
      setState(() => _switchableTenants = tenants);
    }
  }

  Future<void> _openTenantSwitch() async {
    final switched = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TenantSwitchScreen()),
    );
    if (switched == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Organization switched'),
          backgroundColor: FxColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _refreshBookings();
    }
  }

  void _refreshBookings() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.employeeId == null) return;
    Provider.of<AnnouncementProvider>(context, listen: false).fetchInbox(refresh: true);
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    final end = start.add(const Duration(days: 8));
    final fmt = DateFormat('yyyy-MM-dd');
    Provider.of<BookingProvider>(context, listen: false).fetchBookings(
      user!.employeeId!,
      startDate: fmt.format(start),
      endDate: fmt.format(end),
      type: BookingType.home,
    );
  }

  void _fetchHistoryBookings(DateTime date) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.employeeId == null) return;
    final fmt = DateFormat('yyyy-MM-dd');
    Provider.of<BookingProvider>(context, listen: false).fetchBookings(
      user!.employeeId!,
      startDate: fmt.format(date),
      endDate: fmt.format(date),
      type: BookingType.history,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      extendBody: true,
      body: SafeArea(bottom: false, child: _bottomIndex == 1 ? _buildProfilePage() : (_segmentIndex == 0 ? _buildUpcoming() : _buildPast())),
      bottomNavigationBar: FxBottomNav(
        currentIndex: _bottomIndex,
        onTap: _onBottomNavTap,
        items: const [
          FxBottomNavItem(Icons.calendar_month_rounded, 'Bookings'),
          FxBottomNavItem(Icons.person_rounded, 'Profile'),
        ],
      ),
      floatingActionButton: _bottomIndex == 1 ? null : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: _segmentIndex == 0 ? 8 : 24),
            child: Semantics(
              button: true,
              label: 'Emergency SOS',
              child: GestureDetector(
                onTap: _triggerSOS,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: FxColors.error,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: FxShadows.button,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: FxColors.onError, size: 28),
                ),
              ),
            ),
          ),
          if (_segmentIndex == 0)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Semantics(
                button: true,
                label: 'Create new booking',
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateBookingScreen())),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: FxGradients.indigo,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: FxShadows.button,
                    ),
                    child: const Icon(Icons.add_rounded, color: FxColors.onPrimary, size: 28),
                ),
              ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ------------------ UPCOMING (DASHBOARD) ------------------
  Widget _buildUpcoming() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final all = List<Booking>.from(provider.homeBookings);
        final now = DateTime.now();
        final windowStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        final windowEnd = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
        final inWindow = all.where((b) {
          if (b.date == null) return false;
          final d = DateTime.tryParse(b.date!);
          if (d == null) return false;
          final dOnly = DateTime(d.year, d.month, d.day);
          return !dOnly.isBefore(windowStart) && dOnly.isBefore(windowEnd);
        }).toList();

        final activeList = inWindow.where((b) {
          final s = b.status?.toLowerCase();
          if (s == 'ongoing') return true;
          if (s == 'scheduled') return b.routeDetails?['driver_details']?['driver_id'] != null;
          return false;
        }).toList()
          ..sort((a, b) {
            final sa = a.status?.toLowerCase();
            final sb = b.status?.toLowerCase();
            if (sa == 'ongoing' && sb != 'ongoing') return -1;
            if (sb == 'ongoing' && sa != 'ongoing') return 1;
            return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
          });
        final activeRide = activeList.isNotEmpty ? activeList.first : null;

        final scheduled = inWindow.where((b) {
          if (b.id == activeRide?.id) return false;
          final s = b.status?.toLowerCase() ?? '';
          if (s == 'ongoing' || s == 'completed' || s == 'cancelled' || s == 'no-show' || s == 'expired') return false;
          
          // Do not show past non-active rides in upcoming
          if (b.date != null) {
            final d = DateTime.tryParse(b.date!);
            if (d != null) {
              final dOnly = DateTime(d.year, d.month, d.day);
              final todayOnly = DateTime(now.year, now.month, now.day);
              if (dOnly.isBefore(todayOnly)) return false;
            }
          }
          return true;
        }).toList()
          ..sort((a, b) {
            final c = (a.date ?? '').compareTo(b.date ?? '');
            if (c != 0) return c;
            return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
          });

        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final today = scheduled.where((b) => b.date == todayStr).toList();
        final todayActiveCount = activeList.where((b) => b.date == todayStr).length;
        final int todayCount = today.length + todayActiveCount;
        final laterCount = scheduled.length - today.length;

        return RefreshIndicator(
          color: FxColors.primary,
          onRefresh: () async => _refreshBookings(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildAppHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FxSegmented(
                      labels: const ['Upcoming Rides', 'Past Rides'],
                      selectedIndex: _segmentIndex,
                      onChanged: (i) => setState(() {
                        _segmentIndex = i;
                        if (i == 1) _fetchHistoryBookings(_selectedHistoryDate);
                      }),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Scheduled for Today', style: FxText.headlineSm()),
                        FxPill(text: '$todayCount Ride${todayCount == 1 ? '' : 's'}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (provider.isLoading && inWindow.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            SkeletonRideCard(),
                            SkeletonRideCard(),
                            SkeletonRideCard(),
                          ],
                        ),
                      ),
                    if (activeRide != null) _activeRideCard(activeRide),
                    if (activeRide != null) const SizedBox(height: 16),
                    ...today.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _scheduledRideCard(b, isHistory: false),
                        )),
                    if (today.isEmpty && activeRide == null && !provider.isLoading)
                      _emptyState(Icons.directions_car_outlined, 'No rides scheduled for today'),
                    const SizedBox(height: 12),
                    if (laterCount > 0)
                      Row(
                        children: [
                          Text('Coming Up', style: FxText.headlineSm()),
                          const SizedBox(width: 12),
                          FxPill(
                            text: '$laterCount',
                            color: FxColors.onSurfaceVariant,
                            background: FxColors.surfaceContainerLow,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    ...scheduled
                        .where((b) => b.date != todayStr)
                        .map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _scheduledRideCard(b, isHistory: false),
                            )),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppHeader() {
    final user = context.watch<AuthProvider>().user;
    final tenantId = user?.tenantId ?? 'Welcome';
    final canSwitch = _switchableTenants.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: canSwitch
                ? InkWell(
                    onTap: _openTenantSwitch,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(tenantId, style: FxText.headlineMd()),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.swap_horiz_rounded,
                          size: 20,
                          color: FxColors.primary,
                        ),
                      ],
                    ),
                  )
                : Text(tenantId, style: FxText.headlineMd()),
          ),

          Consumer<AnnouncementProvider>(
            builder: (_, ap, __) => Stack(
              clipBehavior: Clip.none,
              children: [
                _iconButton(
                  Icons.campaign_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                  ),
                ),
                if (ap.unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: FxColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ap.unreadCount > 9 ? '9+' : '${ap.unreadCount}',
                        style: FxText.labelSm(color: FxColors.onError).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _iconButton(
            Icons.notifications_outlined,
            semanticLabel: 'Notifications',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTap(int i) {
    setState(() => _bottomIndex = i);
  }

  Booking? _findActiveRide() {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final candidates = List<Booking>.from(provider.homeBookings).where((b) {
      final s = b.status?.toLowerCase();
      if (s == 'ongoing') return true;
      if (s == 'scheduled') {
        return b.routeDetails?['driver_details']?['driver_id'] != null;
      }
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.status == 'Ongoing' && b.status != 'Ongoing') return -1;
        if (b.status == 'Ongoing' && a.status != 'Ongoing') return 1;
        return (a.shiftTime ?? a.pickupTime ?? '')
            .compareTo(b.shiftTime ?? b.pickupTime ?? '');
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<String> _resolveTenantId(Booking b) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsTenantId = prefs.getString('tenant_id');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String resolved = b.tenantId?.toString() ??
        prefsTenantId ??
        auth.user?.tenantId ??
        'SAM001';
    if (resolved == '1' &&
        (prefsTenantId != null || auth.user?.tenantId != null)) {
      resolved = prefsTenantId ?? auth.user!.tenantId!;
    }
    return resolved;
  }

  Future<void> _openTracking() async {
    final active = _findActiveRide();
    if (active == null || active.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No active ride to track right now',
              style: FxText.body(color: FxColors.onPrimary)),
          backgroundColor: FxColors.onSurfaceVariant,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        ),
      );
      return;
    }
    final tenantId = await _resolveTenantId(active);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackDriverScreen(
          booking: {
            'booking_id': active.id,
            'status': active.status,
            'pickup_latitude': active.pickupLatitude,
            'pickup_longitude': active.pickupLongitude,
            'drop_latitude': active.dropLatitude,
            'drop_longitude': active.dropLongitude,
            'pickup_location': active.pickupLocation,
            'drop_location': active.dropLocation,
            'route_details': active.routeDetails,
            'tenant_id': tenantId,
          },
          tenantId: tenantId,
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final name = user?.name ?? 'Employee';
    final rawData = user?.rawEmployeeData ?? const <String, dynamic>{};
    final empCode = rawData['employee_code']?.toString() ?? user?.employeeId?.toString() ?? '';

    const divider = FxColors.surfaceContainerHigh;

    final initials = (name.trim().isEmpty ? 'E' : name.trim())
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    void showNote(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: FxColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Container(
      color: FxColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _profileSummaryCard(
              initials: initials,
              name: name,
              empCode: empCode,
            ),
            const SizedBox(height: 19),
            _menuTile(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              onTap: () => showNote('Help is coming soon.'),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Preferences',
              children: [
                _menuTile(
                  icon: Icons.location_on_outlined,
                  label: 'My Address',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyAddressesScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 19),
            _sectionCard(
              title: 'More',
              children: [
                _menuTile(
                  icon: Icons.feedback_outlined,
                  label: 'App Feedback',
                  onTap: () => showNote('App Feedback is coming soon.'),
                ),
                const _RowDivider(color: divider),
                _menuTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const _RowDivider(color: divider),
                _menuTile(
                  icon: Icons.description_outlined,
                  label: 'Terms Of Usage',
                  onTap: () => showNote('Terms Of Usage is coming soon.'),
                ),
                const _RowDivider(color: divider),
                _menuTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'SOS History',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosHistoryScreen()),
                  ),
                ),
                const _RowDivider(color: divider),
                _menuTile(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  onTap: _handleLogout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileSummaryCard({
    required String initials,
    required String name,
    required String empCode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonalDetailsScreen(
              user: Provider.of<AuthProvider>(context, listen: false).user,
            ),
          ),
        ),
        child: Ink(
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
                child: Text(
                  initials.isEmpty ? 'E' : initials,
                  style: FxText.headlineMd().copyWith(fontSize: 20, color: FxColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: FxText.headlineMd(),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Emp ID ',
                            style: FxText.body(color: FxColors.onSurfaceVariant).copyWith(fontSize: 14),
                          ),
                          TextSpan(
                            text: empCode.isEmpty ? '—' : empCode,
                            style: FxText.headlineMd(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FxColors.primaryContainer.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: FxColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
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
            title,
            style: FxText.headlineMd(),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Icon(icon, size: 20, color: FxColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: FxText.bodyLg(),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: FxColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?', style: FxText.headlineSm()),
        content: Text(
          'You will be returned to the login screen.',
          style: FxText.body(color: FxColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: FxColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  Widget _iconButton(IconData icon, {VoidCallback? onTap, Color? color, String? semanticLabel}) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: FxColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: FxShadows.soft,
            ),
            child: Icon(icon, color: color ?? FxColors.onSurfaceVariant, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _activeRideCard(Booking b) {
    final formattedTime = _formatTime(b);
    final isLogin = b.logType == 'IN';
    final vehicle = b.routeDetails?['vehicle_details']?['vehicle_name']?.toString() ?? 'Vehicle assigned';
    final plate = b.routeDetails?['vehicle_details']?['plate_number']?.toString() ?? '';
    return FxCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!))),
      child: Column(
        children: [
          // Glossy top accent bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: FxGradients.indigoH,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FxMetaLabel('Ongoing Journey'),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(isLogin ? Icons.login_rounded : Icons.logout_rounded, size: 18, color: FxColors.primary),
                              const SizedBox(width: 6),
                              Text(formattedTime, style: FxText.headlineMd(color: FxColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FxPill(
                      text: b.status ?? 'Ongoing',
                      color: FxColors.onPrimaryContainer,
                      background: FxColors.primaryContainer.withOpacity(0.25),
                      pulse: true,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isActiveCardExpanded = !_isActiveCardExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FxColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isActiveCardExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: FxColors.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isActiveCardExpanded) ...[
                  const SizedBox(height: 20),
                  FxRouteTimeline(
                    pickup: b.pickupLocation ?? 'Pickup point',
                    drop: b.dropLocation ?? 'Drop-off',
                    isActive: true,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: FxColors.surfaceContainerLow,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: FxColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.directions_car_rounded,
                          color: FxColors.onSurfaceVariant, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle, style: FxText.titleSm()),
                          if (plate.isNotEmpty)
                            FxMetaLabel(plate),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: FxColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: 'Scan QR to board',
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: FxColors.onSurfaceVariant, size: 20),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NodalScanScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: FxColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: 'Chat with driver',
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: FxColors.onSurfaceVariant, size: 20),
                        onPressed: b.id == null
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      bookingId: b.id!,
                                      driverName: b.routeDetails?['driver_details']?['driver_name']?.toString(),
                                    ),
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: FxColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.map_rounded, color: FxColors.onPrimary, size: 20),
                        onPressed: _openTracking,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduledRideCard(Booking b, {required bool isHistory}) {
    final formattedTime = _formatTime(b);
    final isLogin = b.logType == 'IN';
    final dateLabel = _humanDate(b.date);
    final status = b.status ?? 'Scheduled';
    final statusColor = FxColors.statusColor(status);
    final isLive = status == 'Ongoing';

    return FxTonalCard(
      padding: const EdgeInsets.all(20),
      onTap: () async {
        if (b.id == null) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  BookingDetailsScreen(bookingId: b.id!, isReadOnly: isHistory)),
        );
        if (result == true) {
          isHistory ? _fetchHistoryBookings(_selectedHistoryDate) : _refreshBookings();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxMetaLabel(dateLabel),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(isLogin ? Icons.login_rounded : Icons.logout_rounded, size: 18, color: FxColors.primary),
                        const SizedBox(width: 6),
                        Text(formattedTime, style: FxText.headlineMd()),
                      ],
                    ),
                  ],
                ),
              ),
              FxPill(
                text: status,
                color: statusColor,
                background: statusColor.withOpacity(0.15),
                pulse: isLive,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FxRouteTimeline(
            pickup: b.pickupLocation ?? 'Pickup point',
            drop: b.dropLocation ?? 'Drop-off',
            isActive: isLive,
          ),
          if (!isHistory && _canActOn(status)) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FxSecondaryButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  background: FxColors.surfaceContainerLowest,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EditBookingScreen(bookingId: b.id!)),
                    );
                    if (result == true) _refreshBookings();
                  },
                ),
                FxSecondaryButton(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  background: FxColors.errorContainer.withOpacity(0.1),
                  foreground: FxColors.error,
                  onPressed: () => _showCancelDialog(b),
                ),
              ],
            ),
          ],
          if (isHistory && status == 'Completed') ...[
            const SizedBox(height: 18),
            FxSecondaryButton(
              icon: Icons.star_rounded,
              label: 'Rate this ride',
              background: FxColors.tertiaryContainer.withOpacity(0.25),
              foreground: FxColors.tertiary,
              onPressed: () => _openReview(b),
            ),
          ],
        ],
      ),
    );
  }


  // ------------------ PAST (HISTORY) ------------------
  Widget _buildPast() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final all = List<Booking>.from(provider.historyBookings);
        final selStr = DateFormat('yyyy-MM-dd').format(_selectedHistoryDate);
        final filtered = all.where((b) {
          if (b.date == null) return false;
          final d = DateTime.tryParse(b.date!);
          if (d == null) return false;
          return DateFormat('yyyy-MM-dd').format(d) == selStr;
        }).toList()
          ..sort((a, b) => (b.shiftTime ?? b.pickupTime ?? '')
              .compareTo(a.shiftTime ?? a.pickupTime ?? ''));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildAppHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FxSegmented(
                    labels: const ['Upcoming Rides', 'Past Rides'],
                    selectedIndex: _segmentIndex,
                    onChanged: (i) => setState(() => _segmentIndex = i),
                  ),
                  const SizedBox(height: 24),
                  _historyDateBar(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FxSecondaryButton(
                          icon: Icons.calendar_month_rounded,
                          label: 'Bookings',
                          background: FxColors.primary.withOpacity(0.1),
                          foreground: FxColors.primary,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (provider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          SkeletonRideCard(),
                          SkeletonRideCard(),
                          SkeletonRideCard(),
                        ],
                      ),
                    )
                  else if (filtered.isEmpty)
                    _emptyState(Icons.history_toggle_off,
                        'No rides found for ${DateFormat('MMM d').format(_selectedHistoryDate)}')
                  else
                    ...filtered.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _scheduledRideCard(b, isHistory: true),
                        )),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _historyDateBar() {
    return FxTonalCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, color: FxColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DateFormat('EEEE, MMM d, yyyy').format(_selectedHistoryDate),
              style: FxText.titleSm(),
            ),
          ),
          FxSecondaryButton(
            icon: Icons.edit_calendar_rounded,
            label: 'Change',
            background: FxColors.surfaceContainerLowest,
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedHistoryDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: FxColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _selectedHistoryDate = picked);
                _fetchHistoryBookings(picked);
              }
            },
          ),
        ],
      ),
    );
  }

  // ------------------ HELPERS ------------------

  Widget _emptyState(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FxColors.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: FxColors.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(label, style: FxText.body(color: FxColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(
              'Pull down to refresh',
              style: FxText.bodySm(color: FxColors.outline),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Booking b) {
    final raw = b.shiftTime ?? b.pickupTime ?? '';
    if (raw.isEmpty) return '--:--';
    return formatTimeOfDay(raw, is24Hour: context.watch<TimeFormatProvider>().is24Hour);
  }

  String _humanDate(String? raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dOnly = DateTime(d.year, d.month, d.day);
    if (dOnly == today) return 'TODAY';
    if (dOnly == today.add(const Duration(days: 1))) return 'TOMORROW';
    return DateFormat('EEE, MMM d').format(d).toUpperCase();
  }

  bool _canActOn(String status) {
    final s = status.toLowerCase();
    return s == 'request' || s == 'scheduled';
  }

  void _showCancelDialog(Booking b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel ride?', style: FxText.headlineSm()),
        content: Text(
          'Cancel the ride for ${b.date ?? ''}?',
          style: FxText.body(color: FxColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: FxColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              if (b.id == null) return;
              final r = await Provider.of<BookingProvider>(context, listen: false)
                  .cancelBooking(b.id!);
              if (!mounted) return;
              if (r['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ride cancelled')),
                );
                _refreshBookings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(r['error'] ?? 'Cancellation failed'),
                    backgroundColor: FxColors.error,
                  ),
                );
              }
            },
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReview(Booking b) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: FxColors.primary)),
    );
    final result = await ReviewService().getBookingReview(b.id!);
    if (!mounted) return;
    Navigator.pop(context);
    if (result['success']) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(bookingId: b.id!, existingReview: result['data']),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Error fetching review')),
      );
    }
  }

  Future<void> _triggerSOS() async {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final bookings = List<Booking>.from(provider.homeBookings);
    Booking? active;
    final potential = bookings.where((b) {
      final s = b.status?.toLowerCase();
      return s == 'ongoing' ||
          (s == 'scheduled' && b.routeDetails?['driver_details']?['driver_id'] != null);
    }).toList();
    if (potential.isNotEmpty) {
      potential.sort((a, b) {
        if (a.status == 'Ongoing' && b.status != 'Ongoing') return -1;
        if (b.status == 'Ongoing' && a.status != 'Ongoing') return 1;
        return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
      });
      active = potential.first;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: FxColors.error),
            const SizedBox(width: 8),
            Text('Trigger SOS?', style: FxText.headlineSm(color: FxColors.error)),
          ],
        ),
        content: Text(
          'This sends your location to the transport team immediately.',
          style: FxText.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FxColors.error,
              foregroundColor: FxColors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('TRIGGER SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Triggering SOS...'), duration: Duration(seconds: 1)),
    );
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.triggerGenericSOS(bookingId: active?.id);
    if (!mounted) return;
    if (result['success']) {
      // Try to extract alertId so we can push to SOSDetailsScreen
      final alertId = result['data']?['data']?['alert_id'] ?? result['data']?['alert_id'];
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 56),
          content: Text(
            'SOS alert sent. Help is on the way.',
            textAlign: TextAlign.center,
            style: FxText.body(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (alertId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SOSDetailsScreen(alertId: alertId)),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result['error'] ?? 'Unknown'}'),
          backgroundColor: FxColors.error,
        ),
      );
    }
  }
}

class _RowDivider extends StatelessWidget {
  final Color color;

  const _RowDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 70, right: 16),
      color: color,
    );
  }
}

