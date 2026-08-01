import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/place_model.dart';

/// A place lookup failure carrying a message that is safe to show the user.
///
/// Raw `DioException.toString()` leaks URLs and stack context, so every failure
/// is mapped to something actionable before it reaches the UI.
class PlaceException implements Exception {
  final String message;

  /// True when retrying the same query might succeed (offline, timeout, 5xx).
  final bool isRetryable;

  const PlaceException(this.message, {this.isRetryable = true});

  @override
  String toString() => message;
}

class PlaceRepository {
  /// Requests go through the backend proxy, never to Google/OSM directly.
  ///
  /// That is what keeps GOOGLE_PLACES_API_KEY server-side. Calling the provider
  /// from the app would require shipping the key inside the binary, where it is
  /// extractable — and the Places web-service endpoints cannot be restricted by
  /// app signature or bundle id, only by IP.
  static const _autocompletePath = '/places/autocomplete';
  static const _detailsPath = '/places/details';

  /// Autocomplete suggestions for [input].
  ///
  /// Pass [cancelToken] so a superseded keystroke's request can be aborted; see
  /// PlaceSearchNotifier, which cancels the previous token on every new query.
  Future<List<PlaceSuggestionModel>> getAutocomplete(
    String input, {
    CancelToken? cancelToken,
    String country = 'in',
  }) async {
    try {
      final response = await DioClient.dio.get(
        _autocompletePath,
        queryParameters: {'input': input, 'country': country},
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = (data['data'] as List?) ?? const [];
        return list
            .whereType<Map>()
            .map((e) => PlaceSuggestionModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .where((s) => s.placeId.isNotEmpty)
            .toList();
      }

      throw PlaceException(
        (data is Map ? data['message'] as String? : null) ??
            'Could not load city suggestions.',
      );
    } on DioException catch (e) {
      throw _mapDioError(e, 'Could not load city suggestions.');
    }
  }

  /// Full detail (city/state/country/coordinates) for a selected suggestion.
  Future<PlaceDetailsModel> getDetails(
    String placeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioClient.dio.get(
        _detailsPath,
        queryParameters: {'placeId': placeId},
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] != null) {
        return PlaceDetailsModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }

      throw PlaceException(
        (data is Map ? data['message'] as String? : null) ??
            'Could not load details for that place.',
      );
    } on DioException catch (e) {
      throw _mapDioError(e, 'Could not load details for that place.');
    }
  }

  /// Maps a transport failure to a user-facing [PlaceException].
  ///
  /// Rethrows cancellations untouched — an aborted keystroke is expected
  /// control flow, not something to show the user.
  PlaceException _mapDioError(DioException e, String fallback) {
    if (e.type == DioExceptionType.cancel) {
      throw e;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const PlaceException(
          'City search timed out. Check your connection and try again.',
        );

      case DioExceptionType.connectionError:
        return const PlaceException(
          'No internet connection. Connect and try again.',
        );

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final serverMessage =
            e.response?.data is Map ? e.response?.data['message'] as String? : null;

        if (status == 429) {
          return const PlaceException(
            'Too many searches just now. Please wait a moment and try again.',
          );
        }
        if (status == 401 || status == 403) {
          // The session, not the search, is the problem — retrying won't help.
          return const PlaceException(
            'Your session has expired. Please sign in again.',
            isRetryable: false,
          );
        }
        if (status == 410) {
          return PlaceException(
            serverMessage ?? 'That suggestion expired. Please search again.',
            isRetryable: false,
          );
        }
        if (status != null && status >= 500) {
          return const PlaceException(
            'City search is temporarily unavailable. Please try again.',
          );
        }
        return PlaceException(serverMessage ?? fallback, isRetryable: false);

      default:
        if (e.error is SocketException) {
          return const PlaceException(
            'No internet connection. Connect and try again.',
          );
        }
        return PlaceException(fallback);
    }
  }
}
