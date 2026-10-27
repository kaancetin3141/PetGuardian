import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petguardian/stuff/saved_search_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'user-a';
  const otherUid = 'user-b';

  Future<SavedSearchStore> storeFor(String user) async {
    final prefs = await SharedPreferences.getInstance();
    return SavedSearchStore(prefs, uid: user);
  }

  setUp(() async {
    // In-memory prefs; cleared between tests so ordering assertions are stable.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  group('SavedSearchStore.load', () {
    test('returns an empty list when nothing is stored', () async {
      final store = await storeFor(uid);
      expect(store.load(), isEmpty);
    });

    test('round-trips a search with a species', () async {
      final store = await storeFor(uid);
      const search = SavedSearch(query: 'golden', species: 'Köpek');
      store.add(search);

      final reloaded = await storeFor(uid);
      expect(reloaded.load(), [search]);
    });

    test('round-trips a search with no species', () async {
      final store = await storeFor(uid);
      const search = SavedSearch(query: 'kedi', sortMode: 'oldest');
      store.add(search);

      final reloaded = await storeFor(uid);
      expect(reloaded.load(), [search]);
      expect(reloaded.load().single.species, isNull);
      expect(reloaded.load().single.sortMode, 'oldest');
    });

    test('a query containing the field separator survives a round-trip',
        () async {
      final store = await storeFor(uid);
      const search = SavedSearch(query: 'a|b%c', species: 'Di|ğer');
      store.add(search);

      final reloaded = await storeFor(uid);
      expect(reloaded.load(), [search]);
    });

    test('skips a corrupt entry instead of throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_searches_$uid', [
        'good|Kedi|newest',
        'this-line-has-wrong-field-count',
        '|no-query|newest',
      ]);

      final store = await storeFor(uid);
      expect(store.load().map((s) => s.query), ['good']);
    });

    test('is namespaced per user', () async {
      final storeA = await storeFor(uid);
      storeA.add(const SavedSearch(query: 'only-for-a'));

      final storeB = await storeFor(otherUid);
      expect(storeB.load(), isEmpty);
      expect(storeA.load(), hasLength(1));
    });
  });

  group('SavedSearchStore.add', () {
    test('prepends the newest entry to the front', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'first'));
      final result = store.add(const SavedSearch(query: 'second'));

      expect(result.map((s) => s.query), ['second', 'first']);
    });

    test('replaces a duplicate query+species instead of stacking it', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'kopek', species: 'Köpek'));
      final result = store.add(
        const SavedSearch(query: 'kopek', species: 'Köpek', sortMode: 'nearest'),
      );

      expect(result, hasLength(1));
      expect(result.single.sortMode, 'nearest');
    });

    test('keeps the same query under a different species as separate entries',
        () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'minik', species: 'Kedi'));
      final result = store.add(const SavedSearch(query: 'minik', species: 'Kuş'));

      expect(result, hasLength(2));
    });

    test('trims to the cap, dropping the oldest first', () async {
      final store = await storeFor(uid);
      for (var i = 0; i < SavedSearchStore.maxSavedSearches + 3; i++) {
        store.add(SavedSearch(query: 'q$i'));
      }

      final result = store.load();
      expect(result, hasLength(SavedSearchStore.maxSavedSearches));
      // Newest stays at the front; the 3 oldest (q0..q2) are gone.
      expect(result.first.query, 'q${SavedSearchStore.maxSavedSearches + 2}');
      expect(result.map((s) => s.query), isNot(contains('q0')));
      expect(result.map((s) => s.query), isNot(contains('q1')));
      expect(result.map((s) => s.query), isNot(contains('q2')));
    });

    test('persists across a fresh store instance', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'persisted'));

      final reloaded = await storeFor(uid);
      expect(reloaded.load().single.query, 'persisted');
    });
  });

  group('SavedSearchStore.remove', () {
    test('removes a matching entry', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'keep'));
      store.add(const SavedSearch(query: 'drop'));

      final result = store.remove(const SavedSearch(query: 'drop'));
      expect(result.map((s) => s.query), ['keep']);
    });

    test('is a no-op when the entry is absent', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'keep'));

      final result = store.remove(const SavedSearch(query: 'missing'));
      expect(result, hasLength(1));
      expect(store.load(), hasLength(1));
    });

    test('distinguishes entries that differ only by species', () async {
      final store = await storeFor(uid);
      store.add(const SavedSearch(query: 'minik', species: 'Kedi'));
      store.add(const SavedSearch(query: 'minik', species: 'Kuş'));

      final result = store.remove(const SavedSearch(query: 'minik', species: 'Kedi'));
      expect(result, hasLength(1));
      expect(result.single.species, 'Kuş');
    });
  });
}
