import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../models/booking_model.dart';
import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/review_service.dart';
import '../widgets/fx_widgets.dart';
import 'edit_booking_screen.dart';
import 'review_screen.dart';
import 'track_driver_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final int bookingId;
  final bool isReadOnly;
  const BookingDetailsScreen({super.key, required this.bookingId, this.isReadOnly = false});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingService _bookingService = BookingService();
  final ReviewService _reviewService = ReviewService();
  Booking? _booking;
  String? _tenantId;
  RideReview? _existingReview;
  bool _hasReview = false;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    setState(() => _isLoading = true);
    final result = await _bookingService.getBookingDetails(widget.bookingId);
    final prefs = await SharedPreferences.getInstance();
    final prefsTenantId = prefs.getString('tenant_id');
    if (!mounted) return;
    if (result['success']) {
      final b = result['data'] as Booking;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      String resolvedId = b.tenantId?.toString() ?? prefsTenantId ?? auth.user?.tenantId ?? 'SAM001';
      if (resolvedId == '1' && (prefsTenantId != null || auth.user?.tenantId != null)) {
        resolvedId = prefsTenantId ?? auth.user!.tenantId!;
      }
      RideReview? reviewData;
      bool reviewExists = false;
      if (b.status == 'Completed') {
        try {
          final r = await _reviewService.getBookingReview(widget.bookingId);
          if (r['success'] && r['data'] != null) {
            reviewData = r['data'];
            reviewExists = true;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _booking = b;
        _tenantId = resolvedId;
        _existingReview = reviewData;
        _hasReview = reviewExists;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel booking?', style: FxText.headlineSm()),
        content: Text(
          'Booking #${widget.bookingId} will be cancelled.',
          style: FxText.body(color: FxColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: FxColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isCancelling = true);
    final result = await _bookingService.cancelBooking(widget.bookingId);
    if (!mounted) return;
    setState(() => _isCancelling = false);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled'), backgroundColor: FxColors.primary),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed'), backgroundColor: FxColors.error),
      );
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditBookingScreen(bookingId: widget.bookingId)),
    );
    if (result == true) _fetchBookingDetails();
  }

  void _handleTrack() {
    if (_booking == null || _tenantId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackDriverScreen(
          booking: {
            'booking_id': _booking!.id,
            'status': _booking!.status,
            'pickup_latitude': _booking!.pickupLatitude,
            'pickup_longitude': _booking!.pickupLongitude,
            'drop_latitude': _booking!.dropLatitude,
            'drop_longitude': _booking!.dropLongitude,
            'pickup_location': _booking!.pickupLocation,
            'drop_location': _booking!.dropLocation,
            'route_details': _booking!.routeDetails,
            'tenant_id': _tenantId,
          },
          tenantId: _tenantId,
        ),
      ),
    );
  }

  Future<void> _handleReview() async {
    if (_booking == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReviewScreen(
                bookingId: widget.bookingId,
                existingReview: _existingReview,
              )),
    );
    if (result == true) _fetchBookingDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FxColors.primary))
            : _error != null
                ? _errorView()
                : _booking == null
                    ? Center(child: Text('Booking not found', style: FxText.body()))
                    : _buildBody(),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: FxColors.error, size: 56),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center, style: FxText.body(color: FxColors.error)),
            const SizedBox(height: 16),
            FxPrimaryButton(label: 'Retry', onPressed: _fetchBookingDetails),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final b = _booking!;
    final bookingDate = DateTime.tryParse(b.date ?? '');
    final timeParts = (b.shiftTime ?? b.pickupTime ?? '00:00').split(':');
    final dateLabel = bookingDate != null
        ? '${DateFormat('MMM d, yyyy').format(bookingDate)} • ${timeParts.isNotEmpty ? timeParts[0] : '00'}:${timeParts.length > 1 ? timeParts[1] : '00'}'
        : (b.date ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFutureOrToday = bookingDate != null && !bookingDate.isBefore(today);
    final isRequestOrScheduled = b.status == 'Request' || b.status == 'Scheduled';
    final isCancelled = b.status == 'Cancelled';
    final canCancel = !widget.isReadOnly && isRequestOrScheduled;
    final canEdit = !widget.isReadOnly && (isRequestOrScheduled || (isCancelled && isFutureOrToday));
    final hasDriver = b.routeDetails?['driver_details'] != null;
    final canTrack = ['Scheduled', 'Ongoing'].contains(b.status) && hasDriver;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topNav()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _statusHero(b, dateLabel, canTrack),
              const SizedBox(height: 16),
              _routeCard(b),
              if (b.boardingOtp != null || b.deboardingOtp != null) ...[
                const SizedBox(height: 16),
                _otpCard(b),
              ],
              const SizedBox(height: 16),
              _actionsGrid(b, canCancel: canCancel, canEdit: canEdit),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _topNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('MLT Mobility', style: FxText.headlineMd()),
          const Spacer(),
          const Icon(Icons.notifications_outlined, color: FxColors.primary),
        ],
      ),
    );
  }

  Widget _statusHero(Booking b, String dateLabel, bool canTrack) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: FxGradients.indigo,
            borderRadius: FxRadii.card,
            boxShadow: FxShadows.button,
          ),
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
                        FxMetaLabel('Booking ID', color: FxColors.onPrimary.withOpacity(0.8)),
                        const SizedBox(height: 4),
                        Text('#MLT-${b.id ?? '------'}', style: FxText.headlineLg(color: FxColors.onPrimary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: FxRadii.pill,
                    ),
                    child: Text(
                      (b.status ?? 'Unknown').toUpperCase(),
                      style: FxText.labelSm(color: FxColors.onPrimary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: FxColors.onPrimary.withOpacity(0.9), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel.toString(),
                    style: FxText.body(color: FxColors.onPrimary.withOpacity(0.95)),
                  ),
                ],
              ),
              if (canTrack) ...[
                const SizedBox(height: 24),
                FxPrimaryButton(
                  label: 'Track Driver',
                  leadingIcon: Icons.explore_rounded,
                  onPressed: _handleTrack,
                ),
              ],
            ],
          ),
        ),
        // Decorative flare
        Positioned(
          right: -32,
          top: -32,
          child: IgnorePointer(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FxColors.primaryContainer.withOpacity(0.18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeCard(Booking b) {
    return FxCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip Route', style: FxText.headlineSm()),
          const SizedBox(height: 16),
          FxRouteTimeline(
            pickup: b.pickupLocation ?? 'Pickup point',
            drop: b.dropLocation ?? 'Drop-off',
            pickupLabel: 'PICKUP',
            dropLabel: 'DROP-OFF',
            isActive: b.status == 'Ongoing',
          ),
          const SizedBox(height: 16),
          if ((b.pickupLatitude ?? 0) != 0 && (b.dropLatitude ?? 0) != 0)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: FxColors.surfaceContainer,
                borderRadius: FxRadii.card,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, color: FxColors.primary, size: 36),
                  const SizedBox(height: 4),
                  Text(
                    '${b.pickupLatitude!.toStringAsFixed(4)}, ${b.pickupLongitude!.toStringAsFixed(4)}',
                    style: FxText.bodySm(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _kv('Shift ID', '${b.shiftId ?? "N/A"}'),
          _kv('Shift Time', (b.shiftTime ?? '').substring(0, (b.shiftTime ?? '').length.clamp(0, 5))),
          _kv('Tenant', _tenantId ?? 'N/A'),
          _kv('Type', b.logType ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FxMetaLabel(k),
          Text(v, style: FxText.titleSm()),
        ],
      ),
    );
  }

  Widget _otpCard(Booking b) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFF),
        borderRadius: FxRadii.card,
        border: Border.all(color: FxColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ride Verification', style: FxText.headlineSm(color: FxColors.onPrimaryContainer)),
              const Icon(Icons.verified_user_rounded, color: FxColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (b.boardingOtp != null) Expanded(child: _otpBox('Boarding OTP', b.boardingOtp!)),
              if (b.boardingOtp != null && b.deboardingOtp != null) const SizedBox(width: 12),
              if (b.deboardingOtp != null) Expanded(child: _otpBox('Deboarding OTP', b.deboardingOtp!)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share these codes only with your verified driver.',
            textAlign: TextAlign.center,
            style: FxText.bodySm(color: FxColors.primary.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          FxMetaLabel(label, color: FxColors.primary.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(value, style: FxText.headlineLg(color: FxColors.onPrimaryContainer)),
        ],
      ),
    );
  }

  Widget _actionsGrid(Booking b, {required bool canCancel, required bool canEdit}) {
    final children = <Widget>[];

    if (canEdit) {
      children.add(_bentoAction(
        Icons.edit_calendar_rounded,
        b.status == 'Cancelled' ? 'Reactivate Booking' : 'Edit Booking',
        FxColors.primary,
        _handleEdit,
      ));
    }
    if (canCancel) {
      children.add(_bentoAction(
        Icons.cancel_outlined,
        _isCancelling ? 'Cancelling...' : 'Cancel Ride',
        FxColors.error,
        _isCancelling ? null : _handleCancel,
      ));
    }

    return Column(
      children: [
        if (children.length == 2)
          Row(
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 12),
              Expanded(child: children[1]),
            ],
          )
        else
          ...children,
        if (b.status == 'Completed') ...[
          const SizedBox(height: 12),
          _reviewAction(),
        ],
      ],
    );
  }

  Widget _bentoAction(IconData icon, String label, Color color, VoidCallback? onTap) {
    return Material(
      color: FxColors.surfaceContainerLowest,
      borderRadius: FxRadii.card,
      child: InkWell(
        borderRadius: FxRadii.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(label, style: FxText.title()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewAction() {
    return Material(
      color: FxColors.surfaceContainerLowest,
      borderRadius: FxRadii.card,
      child: InkWell(
        borderRadius: FxRadii.card,
        onTap: _handleReview,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FxColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_rounded, color: FxColors.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hasReview ? 'View Your Review' : 'Rate this Ride', style: FxText.title()),
                    Text(
                      _hasReview
                          ? 'See what you said about this ride'
                          : 'How was your last experience?',
                      style: FxText.bodySm(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: FxColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

