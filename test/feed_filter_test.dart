import 'package:flutter_test/flutter_test.dart';
import 'package:petguardian/stuff/feed_filter.dart';

/// Minimal [FeedPetInfo] implementation for exercising the pure logic.
class FakePet implements FeedPetInfo {
  FakePet({
    required this.id,
    required this.title,
    required this.timestamp,
    this.kinds = '',
    this.location = '',
    this.latitude,
    this.longitude,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final DateTime timestamp;
  @override
  final String kinds;
  @override
  final String location;
  @override
  final double? latitude;
  @override
  final double? longitude;
}

void main() {
  group('normalizeForSearch', () {
    test('folds Turkish characters so ASCII queries match', () {
      expect(normalizeForSearch('Köpek'), 'kopek');
      expect(normalizeForSearch('Şirin'), 'sirin');
      expect(normalizeForSearch('Irmak'), 'irmak');
      expect(normalizeForSearch('Ğöl'), 'gol');
      expect(normalizeForSearch('Çiçek'), 'cicek');
    });

    test('handles dotted capital I (İ) without a combining mark', () {
      // 'İ'.toLowerCase() produces 'i' + U+0307 in Dart; the fold must
      // leave a plain ASCII 'i' behind.
      expect(normalizeForSearch('İstanbul'), 'istanbul');
      expect(normalizeForSearch('İRMAK'), 'irmak');
    });

    test('leaves ASCII text unchanged', () {
      expect(normalizeForSearch('Mama'), 'mama');
      expect(normalizeForSearch(''), '');
    });
  });

  group('distanceKm', () {
    test('is zero for identical points', () {
      expect(distanceKm(41.0082, 28.9784, 41.0082, 28.9784), closeTo(0, 1e-9));
    });

    test('matches the known Istanbul–Ankara distance (~351 km)', () {
      // Istanbul (41.0082, 28.9784) to Ankara (39.9334, 32.8597).
      expect(distanceKm(41.0082, 28.9784, 39.9334, 32.8597), closeTo(351, 3));
    });

    test('is symmetric', () {
      final ab = distanceKm(41.0082, 28.9784, 39.9334, 32.8597);
      final ba = distanceKm(39.9334, 32.8597, 41.0082, 28.9784);
      expect(ab, closeTo(ba, 1e-9));
    });
  });

  group('filterAndSortPets', () {
    final t = DateTime(2026, 1, 1);
    final pets = <FakePet>[
      FakePet(
        id: '1',
        title: 'Pamuk',
        timestamp: t,
        kinds: 'Kedi',
        location: 'Kadıköy',
        latitude: 40.9900,
        longitude: 29.0300,
      ),
      FakePet(
        id: '2',
        title: 'Karakter',
        timestamp: t.add(const Duration(minutes: 1)),
        kinds: 'Köpek',
        location: 'Beşiktaş',
        latitude: 41.0430,
        longitude: 29.0060,
      ),
      FakePet(
        id: '3',
        title: 'Şeker',
        timestamp: t.add(const Duration(minutes: 2)),
        kinds: 'Kuş',
        location: 'Ankara', // no coordinates on purpose
      ),
    ];

    test('empty query returns everything, newest first', () {
      final out = filterAndSortPets(
        pets: pets,
        query: '',
        species: null,
        mode: FeedSortMode.newest,
      );
      expect(out.map((p) => p.id), ['3', '2', '1']);
    });

    test('query matches title case-insensitively', () {
      final out = filterAndSortPets(
        pets: pets,
        query: 'pamuk',
        species: null,
        mode: FeedSortMode.newest,
      );
      expect(out.map((p) => p.id), ['1']);
    });

    test('Turkish-folded query finds a Turkish title', () {
      // ASCII 'seker' must match 'Şeker'.
      final out = filterAndSortPets(
        pets: pets,
        query: 'seker',
        species: null,
        mode: FeedSortMode.newest,
      );
      expect(out.map((p) => p.id), ['3']);
    });

    test('query also matches location and species', () {
      final byLocation = filterAndSortPets(
        pets: pets,
        query: 'kadikoy',
        species: null,
        mode: FeedSortMode.newest,
      );
      expect(byLocation.map((p) => p.id), ['1']);

      final bySpecies = filterAndSortPets(
        pets: pets,
        query: 'kopek',
        species: null,
        mode: FeedSortMode.newest,
      );
      expect(bySpecies.map((p) => p.id), ['2']);
    });

    test('species filter narrows the list', () {
      final out = filterAndSortPets(
        pets: pets,
        query: '',
        species: 'Kedi',
        mode: FeedSortMode.newest,
      );
      expect(out.map((p) => p.id), ['1']);
    });

    test('species filter and query combine', () {
      final out = filterAndSortPets(
        pets: pets,
        query: 'er',
        species: 'Kuş',
        mode: FeedSortMode.newest,
      );
      // 'er' matches Şeker's folded form ('seker') and Karakter's, but the
      // species filter keeps only the Kuş.
      expect(out.map((p) => p.id), ['3']);
    });

    test('oldest sort reverses newest', () {
      final out = filterAndSortPets(
        pets: pets,
        query: '',
        species: null,
        mode: FeedSortMode.oldest,
      );
      expect(out.map((p) => p.id), ['1', '2', '3']);
    });

    test('nearest sort orders by distance and sinks pets without coordinates', () {
      // Viewer at Taksim (41.0370, 28.9850): Beşiktaş is closest,
      // Kadıköy next, and the coordinate-less Kuş goes last even though it
      // has the newest timestamp.
      final out = filterAndSortPets(
        pets: pets,
        query: '',
        species: null,
        mode: FeedSortMode.nearest,
        userLocation: const FeedLocation(41.0370, 28.9850),
      );
      expect(out.map((p) => p.id), ['2', '1', '3']);
    });

    test('nearest sort falls back to newest when no location is known', () {
      final out = filterAndSortPets(
        pets: pets,
        query: '',
        species: null,
        mode: FeedSortMode.nearest,
      );
      expect(out.map((p) => p.id), ['3', '2', '1']);
    });

    test('does not mutate the input list', () {
      final copy = List<FakePet>.from(pets);
      filterAndSortPets(
        pets: pets,
        query: '',
        species: null,
        mode: FeedSortMode.oldest,
      );
      expect(pets, copy);
    });
  });
}
