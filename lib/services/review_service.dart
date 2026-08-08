import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/review_model.dart';
import 'api_service.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> fetchReviewTags(String tenantId) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConstants.reviewTags}?tenant_id=$tenantId',
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final tagsResponse = ReviewTagsResponse.fromJson(response.data['data']);
        return {'success': true, 'data': tagsResponse};
      }
      return {'success': false, 'error': response.data['message'] ?? 'Failed to load review options'};
    } on DioException catch (e) {
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': ApiError.getUserMessage(e)};
      }
      final data = e.response?.data;
      String errorMsg = 'Failed to load review options. Please try again.';
      if (data is Map<String, dynamic> && data['message'] != null) {
        errorMsg = data['message'];
      }
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> submitReview(int bookingId, ReviewSubmission submission) async {
    try {
      final response = await _apiService.dio.post(
        '${ApiConstants.bookingReview}/$bookingId/review',
        data: submission.toJson(),
      );

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return {'success': true, 'data': RideReview.fromJson(response.data['data'])};
      }
      return {'success': false, 'error': response.data['message'] ?? 'Failed to submit review'};
    } on DioException catch (e) {
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': 'No internet connection. Your review was not submitted. Please try again when connected.'};
      }
      if (e.response?.statusCode == 409) {
        return {'success': false, 'error': 'You have already reviewed this ride.', 'code': 409};
      } else if (e.response?.statusCode == 400) {
        return {'success': false, 'error': 'This ride is not completed yet. You can review after the trip ends.', 'code': 400};
      }
      final data = e.response?.data;
      String errorMsg = 'Failed to submit review. Please try again.';
      if (data is Map<String, dynamic> && data['message'] != null) {
        errorMsg = data['message'];
      }
      return {'success': false, 'error': errorMsg, 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> getBookingReview(int bookingId) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConstants.bookingReview}/$bookingId/review',
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return {'success': true, 'data': RideReview.fromJson(response.data['data'])};
      }
      return {'success': false, 'error': 'Failed to load review'};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'success': true, 'data': null};
      }
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': ApiError.getUserMessage(e)};
      }
      final data = e.response?.data;
      String errorMsg = 'Failed to load review. Please try again.';
      if (data is Map<String, dynamic> && data['message'] != null) {
        errorMsg = data['message'];
      }
      return {'success': false, 'error': errorMsg, 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }
}
