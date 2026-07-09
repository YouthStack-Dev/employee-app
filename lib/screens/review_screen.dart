import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../services/review_service.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/star_rating_widget.dart';

class ReviewScreen extends StatefulWidget {
  final int bookingId;
  final RideReview? existingReview;

  const ReviewScreen({super.key, required this.bookingId, this.existingReview});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  bool _isLoadingTags = true;
  bool _isSubmitting = false;

  List<String> _driverTags = [];
  List<String> _vehicleTags = [];

  int? _overallRating;
  int? _driverRating;
  int? _vehicleRating;

  final Set<String> _selectedDriverTags = {};
  final Set<String> _selectedVehicleTags = {};

  final _driverCommentController = TextEditingController();
  final _vehicleCommentController = TextEditingController();

  bool get _isReadOnly => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    if (_isReadOnly) {
      _initReadOnly();
    } else {
      _fetchTags();
    }
  }

  void _initReadOnly() {
    final r = widget.existingReview!;
    _overallRating = r.overallRating;
    _driverRating = r.driverRating;
    _vehicleRating = r.vehicleRating;
    if (r.driverTags != null) _selectedDriverTags.addAll(r.driverTags!);
    if (r.vehicleTags != null) _selectedVehicleTags.addAll(r.vehicleTags!);
    _driverCommentController.text = r.driverComment ?? '';
    _vehicleCommentController.text = r.vehicleComment ?? '';
    setState(() => _isLoadingTags = false);
  }

  Future<void> _fetchTags() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenant = auth.user?.tenantId ?? '';
    if (tenant.isEmpty) {
      if (mounted) setState(() => _isLoadingTags = false);
      return;
    }
    final result = await _reviewService.fetchReviewTags(tenant);
    if (!mounted) return;
    if (result['success']) {
      final tags = result['data'] as ReviewTagsResponse;
      setState(() {
        _driverTags = tags.driverTags;
        _vehicleTags = tags.vehicleTags;
        _isLoadingTags = false;
      });
    } else {
      setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _submit() async {
    if (_overallRating == null &&
        _driverRating == null &&
        _vehicleRating == null &&
        _selectedDriverTags.isEmpty &&
        _selectedVehicleTags.isEmpty &&
        _driverCommentController.text.trim().isEmpty &&
        _vehicleCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least a rating or a comment.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final submission = ReviewSubmission(
      overallRating: _overallRating,
      driverRating: _driverRating,
      driverTags: _selectedDriverTags.toList(),
      driverComment: _driverCommentController.text.trim(),
      vehicleRating: _vehicleRating,
      vehicleTags: _selectedVehicleTags.toList(),
      vehicleComment: _vehicleCommentController.text.trim(),
    );
    final result = await _reviewService.submitReview(widget.bookingId, submission);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted, thank you!'), backgroundColor: FxColors.primary),
      );
      Navigator.pop(context, true);
    } else if (result['code'] == 409) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Unknown error'),
          backgroundColor: FxColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _driverCommentController.dispose();
    _vehicleCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: _isLoadingTags
            ? const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: SkeletonReviewForm(),
              )
            : Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isReadOnly ? 'Your Review' : 'Rate this ride', style: FxText.headlineLg()),
                                const SizedBox(height: 4),
                                Text(
                                  _isReadOnly
                                      ? 'Here\'s what you said about Booking #${widget.bookingId}.'
                                      : 'Help us improve — your feedback shapes the next ride.',
                                  style: FxText.body(color: FxColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _overallCard(),
                          const SizedBox(height: 16),
                          _section(
                            'Driver',
                            Icons.person_rounded,
                            FxColors.primary,
                            _driverRating,
                            (r) => setState(() => _driverRating = r),
                            _driverTags,
                            _selectedDriverTags,
                            _driverCommentController,
                          ),
                          const SizedBox(height: 16),
                          _section(
                            'Vehicle',
                            Icons.directions_car_rounded,
                            FxColors.secondary,
                            _vehicleRating,
                            (r) => setState(() => _vehicleRating = r),
                            _vehicleTags,
                            _selectedVehicleTags,
                            _vehicleCommentController,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _isReadOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: FxPrimaryButton(
                  label: _isSubmitting ? 'Submitting...' : 'Submit review',
                  trailingIcon: Icons.check_rounded,
                  onPressed: _isSubmitting ? null : _submit,
                  loading: _isSubmitting,
                ),
              ),
            ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(_isReadOnly ? 'Your review' : 'Rate your ride', style: FxText.headlineSm(color: FxColors.primary)),
        ],
      ),
    );
  }

  Widget _overallCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: FxGradients.indigo,
        borderRadius: FxRadii.card,
        boxShadow: FxShadows.button,
      ),
      child: Column(
        children: [
          Text('How was your trip overall?', style: FxText.headlineSm(color: FxColors.onPrimary)),
          const SizedBox(height: 18),
          IconTheme(
            data: const IconThemeData(color: FxColors.onPrimary),
            child: StarRatingWidget(
              rating: _overallRating ?? 0,
              starSize: 44,
              onRatingChanged: _isReadOnly ? (_) {} : (r) => setState(() => _overallRating = r),
            ),
          ),
          if (_overallRating != null) ...[
            const SizedBox(height: 8),
            Text(
              ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'][(_overallRating! - 1).clamp(0, 4)],
              style: FxText.titleSm(color: FxColors.onPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    Color tint,
    int? rating,
    void Function(int) onRating,
    List<String> availableTags,
    Set<String> selected,
    TextEditingController commentCtrl,
  ) {
    List<String> tags = List.from(availableTags);
    if (_isReadOnly) {
      for (final t in selected) {
        if (!tags.contains(t)) tags.add(t);
      }
    }
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: FxText.headlineSm()),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: StarRatingWidget(
              rating: rating ?? 0,
              starSize: 34,
              onRatingChanged: _isReadOnly ? (_) {} : onRating,
            ),
          ),
          if (!_isReadOnly || selected.isNotEmpty) ...[
            const SizedBox(height: 18),
            FxMetaLabel('What stood out?'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) {
                final isSel = selected.contains(t);
                return GestureDetector(
                  onTap: _isReadOnly
                      ? null
                      : () {
                          setState(() {
                            isSel ? selected.remove(t) : selected.add(t);
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? FxColors.primary.withOpacity(0.1) : FxColors.surfaceContainerLow,
                      borderRadius: FxRadii.pill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSel) ...[
                          const Icon(Icons.check_rounded, color: FxColors.primary, size: 14),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          t,
                          style: FxText.titleSm(
                            color: isSel ? FxColors.primary : FxColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (!_isReadOnly || commentCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            FxTextField(
              controller: commentCtrl,
              hint: 'Add an optional comment...',
              maxLines: 3,
              readOnly: _isReadOnly,
            ),
          ],
        ],
      ),
    );
  }
}
