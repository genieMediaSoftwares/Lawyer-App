import '../services/calendar_api_service.dart';
import '../../../../models/appointment_model.dart';

class CalendarRepository {
  final CalendarApiService _apiService;

  CalendarRepository(this._apiService);

  Future<List<AppointmentModel>> getAppointments() async {
    return await _apiService.fetchAppointments();
  }
}
