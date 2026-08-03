import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/core/widgets/app_drawer.dart';
import 'package:law/models/activity_model.dart';
import 'package:law/models/client_profile_model.dart';
import 'package:law/models/client_stats_model.dart';
import 'package:law/models/lawyer_model.dart';
import 'package:law/providers/auth_provider.dart';
import 'package:law/providers/lawyer_provider.dart';
import 'package:law/providers/profile_provider.dart';
import 'package:law/repositories/profile_repository.dart';

/// The current user's name and photo live in [authProvider] *and* in caches
/// keyed by their id. Keeping those in step used to be the responsibility of
/// whichever screen performed the edit, so a surface went stale whenever an
/// edit path forgot — the "photo updates in some places but not others" bug.
///
/// These lock in the two properties that replaced that arrangement: a profile
/// write fans the change out itself, and per-user caches do not outlive the
/// user they belong to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile change fan-out', () {
    test('editing the profile refreshes the user-keyed lawyer cache', () async {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          lawyerDetailsProvider.overrideWith((ref, userId) async {
            builds++;
            return _lawyer(userId);
          }),
        ],
      );
      addTearDown(container.dispose);

      final auth = container.read(authProvider.notifier);
      await auth.login(
        'token',
        UserRole.lawyer,
        id: 'user-1',
        name: 'Before',
        email: 'a@example.com',
        mobile: '1',
      );

      await container.read(lawyerDetailsProvider('user-1').future);
      expect(builds, 1);

      // The edit itself must invalidate the cache — no screen involved.
      await auth.updateLocalDetails(name: 'After', photoUrl: '/new.jpg');
      await container.read(lawyerDetailsProvider('user-1').future);

      expect(
        builds,
        2,
        reason: 'the cached lawyer profile should have been refetched',
      );
    });

    test('signing out drops the outgoing user\'s cached profile', () async {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          lawyerDetailsProvider.overrideWith((ref, userId) async {
            builds++;
            return _lawyer(userId);
          }),
        ],
      );
      addTearDown(container.dispose);

      final auth = container.read(authProvider.notifier);
      await auth.login(
        'token',
        UserRole.lawyer,
        id: 'user-1',
        name: 'Before',
        email: 'a@example.com',
        mobile: '1',
      );
      await container.read(lawyerDetailsProvider('user-1').future);
      expect(builds, 1);

      await auth.logout();
      await container.read(lawyerDetailsProvider('user-1').future);

      expect(builds, 2, reason: 'the cache should not survive sign-out');
    });
  });

  group('profileProvider lifetime', () {
    test('a different signed-in user gets a different notifier', () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final auth = container.read(authProvider.notifier);

      await auth.login(
        'token-a',
        UserRole.client,
        id: 'user-a',
        name: 'A',
        email: 'a@example.com',
        mobile: '1',
      );
      final first = container.read(profileProvider.notifier);
      expect(first.userId, 'user-a');

      await auth.logout();
      await auth.login(
        'token-b',
        UserRole.client,
        id: 'user-b',
        name: 'B',
        email: 'b@example.com',
        mobile: '2',
      );
      final second = container.read(profileProvider.notifier);

      expect(
        identical(first, second),
        isFalse,
        reason: 'the previous user\'s profile notifier must not be reused',
      );
      expect(second.userId, 'user-b');
    });

    test('signed out, it holds nothing and does not fetch', () {
      final repository = _FakeProfileRepository();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final state = container.read(profileProvider);

      expect(state.profile, isNull);
      expect(repository.profileFetches, 0);
    });

    test('an ordinary edit does not rebuild it', () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final auth = container.read(authProvider.notifier);
      await auth.login(
        'token',
        UserRole.client,
        id: 'user-a',
        name: 'A',
        email: 'a@example.com',
        mobile: '1',
      );
      final before = container.read(profileProvider.notifier);

      // Name and photo change; the id does not, so nothing should be torn down.
      await auth.updateLocalDetails(name: 'A2', photoUrl: '/p2.jpg');

      expect(identical(before, container.read(profileProvider.notifier)), isTrue);
    });
  });

  group('isDrawerDestinationActive', () {
    test('matches a plain path', () {
      expect(isDrawerDestinationActive('/my-cases', '/my-cases'), isTrue);
      expect(isDrawerDestinationActive('/my-cases', '/advocates'), isFalse);
    });

    test('distinguishes lawyer tabs on the same path', () {
      const leads = '/lawyer-dashboard?tab=2';
      const clients = '/lawyer-dashboard?tab=3';

      expect(isDrawerDestinationActive(leads, leads), isTrue);
      expect(isDrawerDestinationActive(leads, clients), isFalse);
    });

    test('a missing tab means the first one', () {
      expect(
        isDrawerDestinationActive('/lawyer-dashboard', '/lawyer-dashboard?tab=0'),
        isTrue,
      );
      expect(
        isDrawerDestinationActive('/lawyer-dashboard', '/lawyer-dashboard?tab=1'),
        isFalse,
      );
    });

    test('a target without a tab matches the path alone', () {
      expect(
        isDrawerDestinationActive('/messages?foo=bar', '/messages'),
        isTrue,
      );
    });
  });
}

LawyerModel _lawyer(String userId) => LawyerModel.fromJson({
  '_id': userId,
  'user': {'_id': userId, 'fullName': 'Lawyer', 'email': 'l@example.com'},
  'specialization': 'General Practice',
});

class _FakeProfileRepository implements ProfileRepository {
  int profileFetches = 0;

  @override
  Future<ClientProfileModel> getClientProfile() async {
    profileFetches++;
    return ClientProfileModel.fromJson(const {
      '_id': 'user',
      'fullName': 'Client',
      'email': 'c@example.com',
      'mobile': '1',
    });
  }

  @override
  Future<List<ActivityModel>> getClientActivity() async => const [];

  @override
  Future<ClientStatsModel> getClientStats() async =>
      ClientStatsModel.fromJson(const {});

  @override
  Future<ClientProfileModel> updateClientProfile({
    required String fullName,
    required String mobile,
    required String location,
    required String dob,
    required String gender,
    required List<String> languages,
  }) => getClientProfile();

  @override
  Future<ClientProfileModel> uploadProfileImage(
    List<int> bytes,
    String fileName,
  ) => getClientProfile();
}
