import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/review_model.dart';
import 'api_service.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> fetchReviewTags(String tenantId) async {
    try {
      // Tags endpoint might not require auth, but we send it via interceptor anyway
      final response = await _apiService.dio.get(
        '${ApiConstants.reviewTags}?tenant_id=$tenantId',
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final tagsResponse = ReviewTagsResponse.fromJson(response.data['data']);
        return {'success': true, 'data': tagsResponse};
      }
      return {'success': false, 'error': response.data['message'] ?? 'Failed to load tags'};
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMsg = e.message ?? 'Failed to load tags';
      if (data is Map<String, dynamic>) {
        errorMsg = data['message'] ?? errorMsg;
      }
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
      final data = e.response?.data;
      String errorMsg = e.message ?? 'Failed to submit review';
      if (data is Map<String, dynamic>) {
        errorMsg = data['message'] ?? errorMsg;
      }
      
      if (e.response?.statusCode == 409) {
        return {'success': false, 'error': 'You already reviewed this ride.', 'code': 409};
      } else if (e.response?.statusCode == 400) {
        return {'success': false, 'error': 'This ride is not completed yet.', 'code': 400};
      }
      return {'success': false, 'error': errorMsg, 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
        // Review not found (expected if they haven't reviewed)
        return {'success': true, 'data': null}; // Indicate explicitly no review
      }
      
      final data = e.response?.data;
      String errorMsg = e.message ?? 'Failed to load review';
      if (data is Map<String, dynamic>) {
        errorMsg = data['message'] ?? errorMsg;
      }
      return {'success': false, 'error': errorMsg, 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
