import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/appointment_model.dart';

final appointmentsProvider = StateNotifierProvider<AppointmentNotifier, AsyncValue<List<AppointmentModel>>>((ref) {
  return AppointmentNotifier();
});

class AppointmentNotifier extends StateNotifier<AsyncValue<List<AppointmentModel>>> {
  AppointmentNotifier() : super(const AsyncValue.loading()) {
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/appointments");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final appointments = list.map((item) => AppointmentModel.fromJson(item)).toList();
        state = AsyncValue.data(appointments);
      } else {
        state = AsyncValue.error("Failed to load appointments", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> bookAppointment({
    required String lawyerId,
    String? caseId,
    required DateTime date,
    required String timeSlot,
    required String mode,
  }) async {
    try {
      final response = await DioClient.dio.post("/appointments", data: {
        "lawyer": lawyerId,
        "caseId": caseId,
        "date": date.toIso8601String(),
        "timeSlot": timeSlot,
        "mode": mode,
      });

      if (response.data != null && response.data['success'] == true) {
        await fetchAppointments();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final response = await DioClient.dio.delete("/appointments/$appointmentId");
      if (response.data != null && response.data['success'] == true) {
        await fetchAppointments();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
