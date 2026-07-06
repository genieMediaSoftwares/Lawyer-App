import '../../../../core/network/dio_client.dart';
import '../../../../models/appointment_model.dart';

class CalendarApiService {
  Future<List<AppointmentModel>> fetchAppointments() async {
    final response = await DioClient.dio.get("/appointments");
    if (response.data != null && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((item) => AppointmentModel.fromJson(item)).toList();
    }
    throw Exception("Failed to load appointments from server");
  }
}
