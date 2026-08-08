import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
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
      return {'success': false, 'error': 'Unable to load review options. Please try again.'};
    } on DioException catch (e) {
      return {'success': false, 'error': ApiError.resolve(e, feature: 'review', fallback: 'Unable to load review options. Please try again.')};
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
      return {'success': false, 'error': AppErrorMessages.reviewFailed};
    } on DioException catch (e) {
      return {'success': false, 'error': ApiError.resolve(e, feature: 'review', fallback: AppErrorMessages.reviewFailed), 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': AppErrorMessages.reviewFailed};
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
      return {'success': false, 'error': 'Unable to load review.'};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'success': true, 'data': null};
      }
      return {'success': false, 'error': ApiError.resolve(e, feature: 'review', fallback: 'Unable to load review.'), 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }
}
