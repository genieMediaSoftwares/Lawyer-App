import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class PaymentService {
  final Dio _dio = DioClient.dio;

  /// Server-authoritative order creation for consultation payment
  Future<Map<String, dynamic>> createConsultationOrder({
    required String lawyerId,
    String? appointmentId,
    String? caseId,
  }) async {
    try {
      final response = await _dio.post(
        '/payments/create-consultation-order',
        data: {
          'lawyerId': lawyerId,
          ...?appointmentId == null ? null : {'appointmentId': appointmentId},
          ...?caseId == null ? null : {'caseId': caseId},
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Failed to create consultation order.';
      throw Exception(message);
    }
  }

  /// Server-authoritative order creation for subscription plan purchase
  Future<Map<String, dynamic>> createSubscriptionOrder({
    required String plan,
  }) async {
    try {
      final response = await _dio.post(
        '/subscriptions/create-order',
        data: {
          'plan': plan,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Failed to create subscription order.';
      throw Exception(message);
    }
  }

  /// Verify Razorpay payment signature & trigger server settlement
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _dio.post(
        '/payments/verify',
        data: {
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Payment verification failed.';
      throw Exception(message);
    }
  }
}
