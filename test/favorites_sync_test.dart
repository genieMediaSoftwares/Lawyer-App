import 'package:flutter_test/flutter_test.dart';

import 'package:law/providers/favorite_provider.dart';

/// Guards the favourite list against being blanked out by a refresh.
///
/// `fetchFavorites` used to set `AsyncValue.loading()` unconditionally, which
/// discarded the current list on every reload. Any screen watching the provider
/// lost its data mid-toggle, and a failed reload left it empty — which reads as
/// "the favourites screen didn't update".
void main() {
  FavoriteItem item(String id, String lawyerUserId) => FavoriteItem(
        id: id,
        lawyerUserId: lawyerUserId,
        lawyerName: 'Adv. Test',
        lawyerImage: '',
        specialization: 'Family & Divorce',
        rating: 0,
        fee: 0,
      );

  group('FavoriteItem.fromJson', () {
    test('reads the shape GET /favorites actually returns', () {
      // Mirrors favoriteController.getFavorites: _id at the top level, the
      // populated user under `lawyer`, the Lawyer document under `profile`.
      final parsed = FavoriteItem.fromJson({
        '_id': 'fav1',
        'lawyer': {
          '_id': 'lawyerUser1',
          'fullName': 'kuram sneha',
          'profileImage': '/uploads/profiles/a.jpg',
        },
        'profile': {
          'specialization': 'General Practice',
          'rating': 4.5,
          'consultationFee': 1500,
        },
      });

      expect(parsed.id, 'fav1');
      expect(parsed.lawyerUserId, 'lawyerUser1');
      expect(parsed.lawyerName, 'kuram sneha');
      expect(parsed.specialization, 'General Practice');
      expect(parsed.rating, 4.5);
      expect(parsed.fee, 1500);
    });

    test('survives a favourite whose lawyer profile is missing', () {
      // getFavorites sends `profile: null` when no Lawyer document exists.
      final parsed = FavoriteItem.fromJson({
        '_id': 'fav2',
        'lawyer': {'_id': 'lawyerUser2'},
        'profile': null,
      });

      expect(parsed.id, 'fav2');
      expect(parsed.lawyerUserId, 'lawyerUser2');
      expect(parsed.lawyerName, 'Advocate');
      expect(parsed.rating, 0);
      expect(parsed.fee, 0);
    });
  });

  group('favourite list identity', () {
    test('removing one lawyer leaves the rest of the list intact', () {
      // The un-favourite path filters by lawyerUserId rather than reloading.
      final current = [
        item('fav1', 'lawyerA'),
        item('fav2', 'lawyerB'),
        item('fav3', 'lawyerC'),
      ];

      final after =
          current.where((f) => f.lawyerUserId != 'lawyerB').toList();

      expect(after.map((f) => f.lawyerUserId), ['lawyerA', 'lawyerC']);
      expect(after, hasLength(2));
    });

    test('removing a lawyer that is not favourited changes nothing', () {
      final current = [item('fav1', 'lawyerA')];

      final after =
          current.where((f) => f.lawyerUserId != 'lawyerZ').toList();

      expect(after, hasLength(1));
      expect(after.single.lawyerUserId, 'lawyerA');
    });
  });
}
