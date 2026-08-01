import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_model.dart';
import '../repositories/place_repository.dart';
import '../services/place_service.dart';

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository();
});

final placeServiceProvider = Provider<PlaceService>((ref) {
  final repository = ref.watch(placeRepositoryProvider);
  return PlaceService(repository);
});

// ── Search state ────────────────────────────────────────────────────────────

/// Distinguishes "nothing typed yet" from "searched and found nothing", so the
/// field can prompt in one case and say "No matching city found" in the other.
enum PlaceSearchStatus { idle, loading, success, empty, error }

class PlaceSearchState {
  final PlaceSearchStatus status;
  final List<PlaceSuggestionModel> suggestions;
  final String? errorMessage;
  final bool canRetry;

  const PlaceSearchState({
    this.status = PlaceSearchStatus.idle,
    this.suggestions = const [],
    this.errorMessage,
    this.canRetry = false,
  });

  bool get isLoading => status == PlaceSearchStatus.loading;
  bool get hasError => status == PlaceSearchStatus.error;
  bool get isEmpty => status == PlaceSearchStatus.empty;
}

/// Drives city autocomplete: debounces input, caches results, and cancels any
/// superseded request.
class PlaceSearchNotifier extends StateNotifier<PlaceSearchState> {
  PlaceSearchNotifier(this._repository) : super(const PlaceSearchState());

  final PlaceRepository _repository;

  /// Debounce window. Long enough to skip most intermediate keystrokes, short
  /// enough that the list still feels live while typing.
  static const _debounce = Duration(milliseconds: 350);

  /// Below this length results are too broad to be useful and the request is
  /// wasted. The backend applies the same floor.
  static const _minQueryLength = 2;

  /// Recent queries and their results.
  ///
  /// Typing "hyderabad" then backspacing to "hyder" is extremely common, and
  /// every provider behind this is either rate-limited or billed per call.
  /// LinkedHashMap preserves insertion order, so the oldest entry evicts first.
  static const _cacheCapacity = 40;
  final LinkedHashMap<String, List<PlaceSuggestionModel>> _cache =
      LinkedHashMap();

  Timer? _debounceTimer;
  CancelToken? _inFlight;

  /// Monotonic id so a slow earlier response cannot overwrite a newer one even
  /// if cancellation loses the race.
  int _requestSeq = 0;

  String _lastQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inFlight?.cancel('PlaceSearchNotifier disposed');
    super.dispose();
  }

  void search(String rawQuery) {
    final query = rawQuery.trim();

    _debounceTimer?.cancel();

    if (query.length < _minQueryLength) {
      _cancelInFlight();
      _lastQuery = query;
      state = const PlaceSearchState();
      return;
    }

    if (query == _lastQuery && state.status == PlaceSearchStatus.success) {
      return; // Nothing changed; keep what is on screen.
    }
    _lastQuery = query;

    // Cache hit: answer immediately — no network, no debounce, no spinner.
    final cached = _cache[query.toLowerCase()];
    if (cached != null) {
      _cancelInFlight();
      state = PlaceSearchState(
        status:
            cached.isEmpty ? PlaceSearchStatus.empty : PlaceSearchStatus.success,
        suggestions: cached,
      );
      return;
    }

    state = PlaceSearchState(
      status: PlaceSearchStatus.loading,
      // Keep the previous list visible while loading so the dropdown does not
      // flicker on every keystroke.
      suggestions: state.suggestions,
    );

    _debounceTimer = Timer(_debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    _cancelInFlight();

    final token = CancelToken();
    _inFlight = token;
    final seq = ++_requestSeq;

    try {
      final results =
          await _repository.getAutocomplete(query, cancelToken: token);

      // A newer request started while this was in flight — discard this result.
      if (seq != _requestSeq || !mounted) return;

      _cachePut(query.toLowerCase(), results);

      state = PlaceSearchState(
        status: results.isEmpty
            ? PlaceSearchStatus.empty
            : PlaceSearchStatus.success,
        suggestions: results,
      );
    } on DioException catch (e) {
      // Cancellation is expected; leave state for the newer request to set.
      if (e.type == DioExceptionType.cancel) return;
      if (seq != _requestSeq || !mounted) return;

      state = const PlaceSearchState(
        status: PlaceSearchStatus.error,
        errorMessage: 'Could not load city suggestions.',
        canRetry: true,
      );
    } on PlaceException catch (e) {
      if (seq != _requestSeq || !mounted) return;

      state = PlaceSearchState(
        status: PlaceSearchStatus.error,
        errorMessage: e.message,
        canRetry: e.isRetryable,
      );
    } catch (_) {
      if (seq != _requestSeq || !mounted) return;

      state = const PlaceSearchState(
        status: PlaceSearchStatus.error,
        errorMessage: 'Something went wrong while searching. Please try again.',
        canRetry: true,
      );
    }
  }

  /// Re-runs the last query, bypassing any cached failure.
  void retry() {
    if (_lastQuery.length < _minQueryLength) return;
    _cache.remove(_lastQuery.toLowerCase());
    state = PlaceSearchState(
      status: PlaceSearchStatus.loading,
      suggestions: state.suggestions,
    );
    _run(_lastQuery);
  }

  void clear() {
    _debounceTimer?.cancel();
    _cancelInFlight();
    _lastQuery = '';
    state = const PlaceSearchState();
  }

  void _cachePut(String key, List<PlaceSuggestionModel> value) {
    _cache.remove(key); // Re-insert so recency ordering stays correct.
    _cache[key] = value;
    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _cancelInFlight() {
    _inFlight?.cancel('superseded by a newer query');
    _inFlight = null;
  }
}

/// Autocomplete state. `autoDispose` so leaving the screen cancels any pending
/// request and drops the cache.
final placeSearchProvider =
    StateNotifierProvider.autoDispose<PlaceSearchNotifier, PlaceSearchState>(
        (ref) {
  return PlaceSearchNotifier(ref.watch(placeRepositoryProvider));
});

// ── Selection state ─────────────────────────────────────────────────────────

/// The resolved place the user picked, holding the real values the provider
/// returned (city, district, state, country, lat/lng).
///
/// Keyed by family so several fields can coexist — e.g. the post-case form and
/// the profile screen — without overwriting each other. Pass a stable string
/// such as `'post_case'` or `'profile'`.
final selectedPlaceProvider = StateNotifierProvider.family<
    SelectedPlaceNotifier, AsyncValue<PlaceDetailsModel?>, String>((ref, _) {
  return SelectedPlaceNotifier(ref.watch(placeRepositoryProvider));
});

class SelectedPlaceNotifier
    extends StateNotifier<AsyncValue<PlaceDetailsModel?>> {
  SelectedPlaceNotifier(this._repository) : super(const AsyncValue.data(null));

  final PlaceRepository _repository;
  CancelToken? _inFlight;

  @override
  void dispose() {
    _inFlight?.cancel('SelectedPlaceNotifier disposed');
    super.dispose();
  }

  /// Resolves [suggestion] to full details and stores it.
  ///
  /// Returns the resolved place, or null if resolution failed, so the caller can
  /// decide whether to close the dropdown.
  Future<PlaceDetailsModel?> select(PlaceSuggestionModel suggestion) async {
    _inFlight?.cancel('superseded by a newer selection');
    final token = CancelToken();
    _inFlight = token;

    state = const AsyncValue.loading();

    try {
      final details =
          await _repository.getDetails(suggestion.placeId, cancelToken: token);
      if (!mounted) return null;
      state = AsyncValue.data(details);
      return details;
    } on DioException catch (e, st) {
      if (e.type == DioExceptionType.cancel) return null;
      if (!mounted) return null;
      state = AsyncValue.error(
        const PlaceException('Could not load details for that place.'),
        st,
      );
      return null;
    } catch (e, st) {
      if (!mounted) return null;
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Seeds the field from an already-stored value (e.g. an existing profile)
  /// without a network call.
  void hydrate(PlaceDetailsModel? place) {
    state = AsyncValue.data(place);
  }

  void clear() {
    _inFlight?.cancel('selection cleared');
    state = const AsyncValue.data(null);
  }
}
