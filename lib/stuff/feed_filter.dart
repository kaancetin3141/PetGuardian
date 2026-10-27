// Pure, UI-free feed filtering and sorting.
//
// Research into comparable pet-adoption apps (PetFinder et al., 2026)
// showed three feed capabilities this app lacked: species filtering,
// distance-based sorting, and distance badges on cards. All three live
// here as pure functions so they can be unit-tested without Firebase or
// widgets.

import 'dart:math' as math;

/// The minimal pet shape the feed needs for filtering and sorting.
///
/// `home_page.dart`'s `ImageInfo` implements this, so the real feed data
/// flows through without a copy step.
abstract interface class FeedPetInfo {
  String get id;
  String get title;
  DateTime get timestamp;

  /// Species label as stored by `add_pet_page.dart` (`Kinds`), e.g. 'Köpek'.
  String get kinds;

  /// Free-text location label, e.g. 'Kadıköy'.
  String get location;

  double? get latitude;
  double? get longitude;
}

/// The viewer's position, used for "nearest first" sorting.
class FeedLocation {
  const FeedLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// How the feed is ordered.
enum FeedSortMode {
  newest,
  oldest,

  /// Nearest first; falls back to [newest] when no [FeedLocation] is known.
  nearest,
}

/// Options shown in the species filter bar. Mirrors the `Kinds` dropdown
/// in `add_pet_page.dart`.
const List<String> kFeedSpeciesOptions = <String>[
  'Kedi',
  'Köpek',
  'Kuş',
  'Balık',
  'Diğer',
];

/// Lowercases [input] and folds Turkish diacritics, so that a query of
/// 'kopek' matches 'Köpek' and 'IRMAK' matches 'ırmak'.
String normalizeForSearch(String input) {
  var folded = input.toLowerCase();
  // Dart lowercases 'İ' to 'i' + U+0307 combining dot; drop the combining
  // mark so the result is plain ASCII 'i'.
  folded = folded.replaceAll('\u0307', '');
  return folded
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

/// Great-circle distance between two WGS84 coordinates, in kilometres.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Filters [pets] by [query] and [species], then orders them by [mode].
///
/// A pet matches [query] when the normalised query is empty or appears in
/// its title, location or species. Pets without coordinates always sink
/// to the bottom under [FeedSortMode.nearest] rather than being dropped.
List<T> filterAndSortPets<T extends FeedPetInfo>({
  required List<T> pets,
  required String query,
  required String? species,
  required FeedSortMode mode,
  FeedLocation? userLocation,
}) {
  final normalizedQuery = normalizeForSearch(query.trim());
  final result = pets.where((pet) {
    final matchesQuery = normalizedQuery.isEmpty ||
        normalizeForSearch(pet.title).contains(normalizedQuery) ||
        normalizeForSearch(pet.location).contains(normalizedQuery) ||
        normalizeForSearch(pet.kinds).contains(normalizedQuery);
    final matchesSpecies = species == null || pet.kinds == species;
    return matchesQuery && matchesSpecies;
  }).toList();

  switch (mode) {
    case FeedSortMode.newest:
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    case FeedSortMode.oldest:
      result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    case FeedSortMode.nearest:
      final origin = userLocation;
      if (origin == null) {
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        double? kmOf(FeedPetInfo pet) =>
            (pet.latitude == null || pet.longitude == null)
                ? null
                : distanceKm(
                    origin.latitude, origin.longitude, pet.latitude!, pet.longitude!);
        result.sort((a, b) {
          final ka = kmOf(a);
          final kb = kmOf(b);
          if (ka == null && kb == null) {
            return b.timestamp.compareTo(a.timestamp);
          }
          if (ka == null) return 1;
          if (kb == null) return -1;
          return ka.compareTo(kb);
        });
      }
  }
  return result;
}
