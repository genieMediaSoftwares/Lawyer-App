import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law/models/place_model.dart';
import 'package:law/providers/place_provider.dart';
import 'package:law/repositories/place_repository.dart';

/// Records whether the repository was actually reached, so a test can tell
/// "no results" apart from "the request never happened".
class _RecordingPlaceRepository extends PlaceRepository {
  int autocompleteCalls = 0;
  final List<String> queries = [];

  @override
  Future<List<PlaceSuggestionModel>> getAutocomplete(
    String input, {
    CancelToken? cancelToken,
    String country = 'in',
  }) async {
    autocompleteCalls++;
    queries.add(input);
    return [
      PlaceSuggestionModel(
        description: 'Hyderabad, Telangana, India',
        placeId: 'osm:N:1',
      ),
    ];
  }
}

void main() {
  group('PlaceSearchNotifier', () {
    test(
      'issues a debounced request when only the overlay watches the provider '
      '(reproduces the blank-dropdown bug)',
      () async {
        final repo = _RecordingPlaceRepository();
        final container = ProviderContainer(
          overrides: [placeRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        // Mirrors CityAutocompleteField: the field keeps the provider alive
        // with a `ref.watch` (this listener) while driving it through
        // `ref.read(...).search(...)`.
        //
        // Without that listener this test fails with 0 calls: the provider is
        // `autoDispose`, so it was torn down before the 350ms debounce fired
        // and `dispose()` cancelled the pending timer. That was the real cause
        // of the blank dropdown — the request was never sent at all.
        container.listen(placeSearchProvider, (_, _) {});

        container.read(placeSearchProvider.notifier).search('hyd');

        // Wait past the 350ms debounce.
        await Future<void>.delayed(const Duration(milliseconds: 700));

        expect(
          repo.autocompleteCalls,
          1,
          reason: 'the debounced request should have reached the repository',
        );
        expect(container.read(placeSearchProvider).suggestions, isNotEmpty);
      },
    );

    test('debounce collapses rapid keystrokes into one request', () async {
      final repo = _RecordingPlaceRepository();
      final container = ProviderContainer(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(placeSearchProvider.notifier);
      // Keep a listener alive so this test isolates debounce behaviour from
      // any lifecycle concerns.
      container.listen(placeSearchProvider, (_, _) {});

      notifier.search('h');
      notifier.search('hy');
      notifier.search('hyd');
      notifier.search('hyde');

      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(repo.autocompleteCalls, 1);
      expect(repo.queries.single, 'hyde');
    });

    test('a query shorter than the 2-char floor issues no request', () async {
      final repo = _RecordingPlaceRepository();
      final container = ProviderContainer(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(placeSearchProvider, (_, _) {});

      container.read(placeSearchProvider.notifier).search('h');
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(repo.autocompleteCalls, 0);
      expect(container.read(placeSearchProvider).status, PlaceSearchStatus.idle);
    });

    test('a repeated query is served from cache without a second request',
        () async {
      final repo = _RecordingPlaceRepository();
      final container = ProviderContainer(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(placeSearchProvider, (_, _) {});

      final notifier = container.read(placeSearchProvider.notifier);

      notifier.search('hyd');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(repo.autocompleteCalls, 1);

      // Simulate backspacing to a different query and returning to 'hyd'.
      notifier.search('hyder');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      notifier.search('hyd');
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(
        repo.autocompleteCalls,
        2,
        reason: '"hyd" should have come from the cache the second time',
      );
    });
  });
}
