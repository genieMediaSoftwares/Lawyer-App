import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/calendar_api_service.dart';
import '../repositories/calendar_repository.dart';
import '../../../../models/appointment_model.dart';

final calendarApiServiceProvider = Provider<CalendarApiService>((ref) => CalendarApiService());

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final apiService = ref.watch(calendarApiServiceProvider);
  return CalendarRepository(apiService);
});

// Selected Date Provider — defaults to today
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// Focused Month/Year Provider — defaults to current month
final focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// StateNotifierProvider for fetching MongoDB appointments
final calendarAppointmentsProvider = StateNotifierProvider<CalendarAppointmentsNotifier, AsyncValue<List<AppointmentModel>>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return CalendarAppointmentsNotifier(repository);
});

class CalendarAppointmentsNotifier extends StateNotifier<AsyncValue<List<AppointmentModel>>> {
  final CalendarRepository _repository;

  CalendarAppointmentsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadAppointments();
  }

  Future<void> loadAppointments() async {
    try {
      state = const AsyncValue.loading();
      final appointments = await _repository.getAppointments();
      state = AsyncValue.data(appointments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
