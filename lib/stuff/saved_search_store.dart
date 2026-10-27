import 'package:shared_preferences/shared_preferences.dart';

/// A user's saved search: the query text plus the species and sort mode it was
/// captured with. Persisted locally (not in Firestore) so restoring a search
/// is instant and works offline.
class SavedSearch {
  const SavedSearch({
    required this.query,
    this.species,
    this.sortMode = 'newest',
  });

  final String query;

  /// Species label (e.g. 'Köpek'), or null for "all species".
  final String? species;

  /// Serialized [FeedSortMode] name: 'newest' | 'oldest' | 'nearest'.
  final String sortMode;

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
        query: json['query']?.toString() ?? '',
        species: json['species']?.toString(),
        sortMode: json['sortMode']?.toString() ?? 'newest',
      );

  Map<String, dynamic> toJson() => {
        'query': query,
        'species': species,
        'sortMode': sortMode,
      };

  @override
  bool operator ==(Object other) =>
      other is SavedSearch &&
      other.query == query &&
      other.species == species &&
      other.sortMode == sortMode;

  @override
  int get hashCode => Object.hash(query, species, sortMode);
}

/// Persists the signed-in user's saved searches on-device.
///
/// Storage is namespaced by user ID so switching accounts never leaks one
/// user's saved searches into another's. The list is capped at
/// [maxSavedSearches]; saving beyond the cap drops the oldest entry first.
///
/// This class takes a [SharedPreferences] instance rather than calling the
/// global singleton, so tests can drive it with an in-memory fake.
class SavedSearchStore {
  SavedSearchStore(this._prefs, {required this.uid});

  static const int maxSavedSearches = 10;

  final SharedPreferences _prefs;

  /// The auth UID whose saved searches are being managed.
  final String uid;

  /// Key is namespaced per user: `saved_searches_<uid>`.
  String get _key => 'saved_searches_$uid';

  /// Reads the persisted list, newest first. A corrupt or absent entry is
  /// skipped rather than throwing, so one bad record cannot break the whole
  /// list.
  List<SavedSearch> load() {
    final raw = _prefs.getStringList(_key);
    if (raw == null) return const [];
    final out = <SavedSearch>[];
    for (final line in raw) {
      final decoded = _decode(line);
      if (decoded != null) out.add(decoded);
    }
    return out;
  }

  /// Adds [search] to the front, dropping any duplicate (same query + species)
  /// and trimming to [maxSavedSearches]. Returns the new list.
  List<SavedSearch> add(SavedSearch search) {
    final current = load()
        .where((s) => !(s.query == search.query && s.species == search.species))
        .toList();
    final updated = [search, ...current].take(maxSavedSearches).toList();
    _persist(updated);
    return updated;
  }

  /// Removes the entry matching [search]. Returns the new list.
  List<SavedSearch> remove(SavedSearch search) {
    final updated = load().where((s) => s != search).toList();
    _persist(updated);
    return updated;
  }

  void _persist(List<SavedSearch> searches) {
    // Each entry is stored as a compact `query|species|sortMode` line; an
    // absent species is encoded as an empty segment.
    final encoded = searches
        .map((s) =>
            '${_escape(s.query)}|${_escape(s.species ?? '')}|${s.sortMode}')
        .toList();
    // Fire-and-forget: SharedPreferences writes are already async under the
    // hood and a failure here must not break the UI.
    _prefs.setStringList(_key, encoded);
  }

  SavedSearch? _decode(String line) {
    final parts = line.split('|');
    if (parts.length != 3) return null;
    final query = _unescape(parts[0]);
    final speciesRaw = _unescape(parts[1]);
    if (query.isEmpty) return null;
    return SavedSearch(
      query: query,
      species: speciesRaw.isEmpty ? null : speciesRaw,
      sortMode: parts[2],
    );
  }

  // `|` is the field separator, so it must not survive inside a value.
  static String _escape(String value) =>
      value.replaceAll('%', '%25').replaceAll('|', '%7C');

  static String _unescape(String value) =>
      value.replaceAll('%7C', '|').replaceAll('%25', '%');
}
