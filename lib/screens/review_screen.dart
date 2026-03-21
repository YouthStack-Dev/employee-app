import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../services/review_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/star_rating_widget.dart';
import '../constants/app_colors.dart';

class ReviewScreen extends StatefulWidget {
  final int bookingId;
  final RideReview? existingReview;

  const ReviewScreen({
    Key? key,
    required this.bookingId,
    this.existingReview,
  }) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  bool _isLoadingTags = true;
  bool _isSubmitting = false;
  
  List<String> _driverTags = [];
  List<String> _vehicleTags = [];

  // Form State
  int? _overallRating;
  int? _driverRating;
  int? _vehicleRating;
  
  final Set<String> _selectedDriverTags = {};
  final Set<String> _selectedVehicleTags = {};
  
  final TextEditingController _driverCommentController = TextEditingController();
  final TextEditingController _vehicleCommentController = TextEditingController();

  bool get _isReadOnly => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    if (_isReadOnly) {
      _initializeReadOnlyState();
    } else {
      _fetchTags();
    }
  }

  void _initializeReadOnlyState() {
    final review = widget.existingReview!;
    _overallRating = review.overallRating;
    _driverRating = review.driverRating;
    _vehicleRating = review.vehicleRating;
    
    if (review.driverTags != null) _selectedDriverTags.addAll(review.driverTags!);
    if (review.vehicleTags != null) _selectedVehicleTags.addAll(review.vehicleTags!);
    
    _driverCommentController.text = review.driverComment ?? '';
    _vehicleCommentController.text = review.vehicleComment ?? '';
    
    setState(() {
      _isLoadingTags = false;
    });
  }

  Future<void> _fetchTags() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = authProvider.user?.tenantId ?? '';
    
    if (tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingTags = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error: Missing Tenant ID.')),
        );
      }
      return;
    }

    final result = await _reviewService.fetchReviewTags(tenantId);
    
    if (mounted) {
      if (result['success']) {
        final tagsData = result['data'] as ReviewTagsResponse;
        setState(() {
          _driverTags = tagsData.driverTags;
          _vehicleTags = tagsData.vehicleTags;
          _isLoadingTags = false;
        });
      } else {
        // Fallback to empty if fails
        setState(() {
          _isLoadingTags = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load Review Tags: ${result['error']}')),
        );
      }
    }
  }

  Future<void> _submitReview() async {
    // Validate that at least one field is filled
    if (_overallRating == null && _driverRating == null && _vehicleRating == null &&
        _selectedDriverTags.isEmpty && _selectedVehicleTags.isEmpty &&
        _driverCommentController.text.trim().isEmpty && _vehicleCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least a rating or a comment.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

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

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully! Thank you.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true indicates review was submitted
      } else {
        if (result['code'] == 409) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('You have already reviewed this trip.'),
               backgroundColor: Colors.blue,
             ),
           );
           Navigator.pop(context, true); // Treat 409 "already reviewed" as completion
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(result['error'] ?? 'An unknown error occurred.'),
               backgroundColor: Colors.red,
             ),
           );
        }
      }
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
      appBar: AppBar(
        title: Text(_isReadOnly ? 'Your Review' : 'Rate Your Ride'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: _isReadOnly ? null : [
          TextButton(
             onPressed: _isSubmitting ? null : _submitReview,
             child: _isSubmitting 
               ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
               : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoadingTags
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverallSection(),
                  const SizedBox(height: 24),
                  _buildDriverSection(),
                  const SizedBox(height: 24),
                  _buildVehicleSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallSection() {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'How was your trip overall?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StarRatingWidget(
              rating: _overallRating ?? 0,
              starSize: 42,
              onRatingChanged: _isReadOnly ? (_) {} : (rating) {
                setState(() => _overallRating = rating);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverSection() {
    return _buildSection(
      title: 'Driver',
      icon: Icons.person,
      rating: _driverRating,
      onRatingChanged: (r) => setState(() => _driverRating = r),
      availableTags: _driverTags,
      selectedTags: _selectedDriverTags,
      commentController: _driverCommentController,
    );
  }

  Widget _buildVehicleSection() {
    return _buildSection(
      title: 'Vehicle',
      icon: Icons.directions_car,
      rating: _vehicleRating,
      onRatingChanged: (r) => setState(() => _vehicleRating = r),
      availableTags: _vehicleTags,
      selectedTags: _selectedVehicleTags,
      commentController: _vehicleCommentController,
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    int? rating,
    required Function(int) onRatingChanged,
    required List<String> availableTags,
    required Set<String> selectedTags,
    required TextEditingController commentController,
  }) {
    // If read-only, ensure all selected tags are visually present even if not currently active on server
    List<String> displayTags = List.from(availableTags);
    if (_isReadOnly) {
       for (var tag in selectedTags) {
          if (!displayTags.contains(tag)) displayTags.add(tag);
       }
    }

    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: StarRatingWidget(
                rating: rating ?? 0,
                onRatingChanged: _isReadOnly ? (_) {} : onRatingChanged,
              ),
            ),
            if (!_isReadOnly || selectedTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('What stood out?', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _isReadOnly 
                    ? selectedTags.map((tag) => _buildReadOnlyChip(tag)).toList()
                    : displayTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
              ),
            ],
            if (!_isReadOnly || commentController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                readOnly: _isReadOnly,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add an optional comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: _isReadOnly ? Colors.grey.shade50 : Colors.white,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      side: const BorderSide(color: AppColors.primary, width: 1),
    );
  }
}
