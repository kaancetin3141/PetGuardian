import 'dart:async';

import 'package:petguardian/pages/messages/chat_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petguardian/pages/account_page.dart';
import 'package:petguardian/pages/notification_page.dart';
import 'package:petguardian/pages/pet_detail_page.dart';
import 'package:petguardian/pages/shop_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../stuff/app_network_image.dart';
import '../stuff/feed_filter.dart';
import '../stuff/saved_search_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ImageInfo> imageList = [];
  List<ImageInfo> filteredList = [];
  TextEditingController searchController = TextEditingController();
  int _unreadMessagesCount = 0;
  int _unreadNotificationsCount = 0;
  // Distinguish "still loading" from "loaded but empty" so the feed does not
  // flash the empty state (or a blank grid) while the first fetch is in flight.
  bool _isLoading = true;
  bool _loadFailed = false;

  // Feed filtering / sorting (see stuff/feed_filter.dart). The species chip
  // is null for "all"; distance sort is resolved lazily from the device GPS.
  String? _selectedSpecies;
  FeedSortMode _sortMode = FeedSortMode.newest;
  FeedLocation? _userLocation;
  bool _isLocating = false;

  // Pet IDs whose entrance animation has already played. Re-running the
  // filter rebuilds the grid, and remounting a card must not replay its
  // slide-in or the feed would "cascade" on every keystroke.
  final Set<String> _animatedIn = {};

  // Saved searches (see stuff/saved_search_store.dart). Loaded lazily for the
  // signed-in user; null until the first read resolves so the menu does not
  // flash an empty list before prefs are available.
  SavedSearchStore? _searchStore;
  List<SavedSearch> _savedSearches = const [];

  @override
  void initState() {
    super.initState();
    _reload();
    searchController.addListener(filterImages);
    _listenToUnreadCounts();
    _loadSavedSearches();
  }

  /// Loads this user's saved searches. Prefs are keyed by UID, so signing in
  /// as someone else never surfaces the previous account's searches.
  Future<void> _loadSavedSearches() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final store = SavedSearchStore(prefs, uid: user.uid);
      setState(() {
        _searchStore = store;
        _savedSearches = store.load();
      });
    } catch (e) {
      // Saved searches are a convenience; a prefs failure must not block the
      // feed from loading.
      debugPrint('Kay�tl� aramalar y�klenemedi: $e');
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final data = await fetchImageDataFromFirestore();
      if (!mounted) return;
      setState(() {
        imageList = data;
        _isLoading = false;
      });
      // Re-apply whatever filter/sort is active so a manual refresh does not
      // silently reset the user's chip and sort choices.
      filterImages();
    } catch (e) {
      if (!mounted) return;
      debugPrint('Pet akışı yüklenemedi: $e');
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  final List<StreamSubscription<QuerySnapshot>> _subscriptions = [];

  @override
  void dispose() {
    searchController.dispose();
    // These listeners used to outlive the widget: nothing cancelled them, so
    // every visit to this page left two live Firestore listeners behind.
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  /// The current filter as a [SavedSearch], used for both saving and
  /// de-duplication. Reused by the menu so what is saved always matches what
  /// is on screen.
  SavedSearch get _currentSearch => SavedSearch(
        query: searchController.text.trim(),
        species: _selectedSpecies,
        sortMode: _sortMode.name,
      );

  /// Whether the on-screen filter differs from an empty search, i.e. whether
  /// the "save" action is meaningful right now.
  bool get _hasActiveFilter =>
      searchController.text.trim().isNotEmpty || _selectedSpecies != null;

  /// Applies [search] to the live filter state and re-runs filtering.
  void _applySavedSearch(SavedSearch search) {
    setState(() {
      searchController.text = search.query;
      _selectedSpecies = search.species;
      _sortMode = FeedSortMode.values.firstWhere(
        (m) => m.name == search.sortMode,
        orElse: () => FeedSortMode.newest,
      );
    });
    if (_sortMode == FeedSortMode.nearest) {
      _ensureUserLocation();
    } else {
      filterImages();
    }
  }

  /// Persists the current filter as a saved search and refreshes the menu.
  Future<void> _saveCurrentSearch() async {
    final store = _searchStore;
    if (store == null || !_hasActiveFilter) return;
    final updated = store.add(_currentSearch);
    setState(() => _savedSearches = updated);
    _showSnack('Arama kaydedildi.');
  }

  /// Removes [search] from the saved list.
  Future<void> _deleteSavedSearch(SavedSearch search) async {
    final store = _searchStore;
    if (store == null) return;
    final updated = store.remove(search);
    setState(() => _savedSearches = updated);
    _showSnack('Kay�tl� arama silindi.');
  }

  /// Applies the active filter and clears the search box, returning the feed
  /// to its default (all species, newest first) state.
  void _clearFilters() {
    setState(() {
      searchController.clear();
      _selectedSpecies = null;
      _sortMode = FeedSortMode.newest;
    });
    filterImages();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void filterImages() {
    final mode = _sortMode;
    setState(() {
      filteredList = filterAndSortPets(
        pets: imageList,
        query: searchController.text,
        species: _selectedSpecies,
        mode: mode,
        userLocation: mode == FeedSortMode.nearest ? _userLocation : null,
      );
    });
  }

  /// Distance from the viewer to [pet] in km, or null when either side has
  /// no coordinates (or the viewer location is not resolved yet).
  double? _petDistanceKm(ImageInfo pet) {
    final origin = _userLocation;
    if (origin == null || pet.latitude == null || pet.longitude == null) {
      return null;
    }
    return distanceKm(origin.latitude, origin.longitude, pet.latitude!, pet.longitude!);
  }

  /// Renders a distance as "850 m" below a kilometre and "2,4 km" above,
  /// with a comma decimal separator to match the Turkish UI.
  static String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Resolves the device position once, so "nearest first" sorting has an
  /// origin. Falls back silently to newest-first ordering when the user
  /// denies permission or geolocation is unavailable (e.g. plain HTTP web).
  Future<void> _ensureUserLocation() async {
    if (_userLocation != null || _isLocating) return;
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Konum izni verilmedi; mesafe s�ralamas� yap�lamayacak.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _userLocation = FeedLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Konum al�namad�: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
        // Re-run the filter so the distance ordering applies now that an
        // origin exists.
        filterImages();
      }
    }
  }

  void _listenToUnreadCounts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to unread messages count
    _subscriptions.add(FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        final count = unreadCount[user.uid];
        if (count is int) {
          totalUnread += count;
        } else if (count is num) {
          totalUnread += count.toInt();
        }
      }
      if (mounted) {
        setState(() {
          _unreadMessagesCount = totalUnread;
        });
      }
    }));

    // Listen to unread notifications count
    _subscriptions.add(FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = snapshot.docs.length;
        });
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 100),
            Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 12),
            Text('PetGuardian', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            SizedBox(width: 12),
            Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
          ],
        ),
        actions: [
          // Notifications with badge
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationPage()),
                  );
                },
                icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary),
                tooltip: _unreadNotificationsCount > 0
                    ? 'Bildirimler, $_unreadNotificationsCount okunmamış'
                    : 'Bildirimler',
              ),
              if (_unreadNotificationsCount > 0)
                _animatedCountBadge(_unreadNotificationsCount),
            ],
          ),
          // Messages with badge
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  final currentUserUID = user?.uid ?? '';

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatListPage(currentUserUID: currentUserUID),
                    ),
                  );
                },
                icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                tooltip: _unreadMessagesCount > 0
                    ? 'Mesajlar, $_unreadMessagesCount okunmamış'
                    : 'Mesajlar',
              ),
              if (_unreadMessagesCount > 0)
                _animatedCountBadge(_unreadMessagesCount),
            ],
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          // Search field + species chips + sort menu.
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    hintText: 'Arama yapın',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    prefixIcon:
                        Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Aramay� temizle',
                            onPressed: () => searchController.clear(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          tooltip: 'Kay�tl� aramalar',
                          onPressed: _showSearchMenu,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: const Text('T�m�'),
                                selected: _selectedSpecies == null,
                                onSelected: (_) {
                                  setState(() => _selectedSpecies = null);
                                  filterImages();
                                },
                              ),
                            ),
                            ...kFeedSpeciesOptions.map(
                              (species) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(species),
                                  selected: _selectedSpecies == species,
                                  onSelected: (_) {
                                    setState(() => _selectedSpecies = species);
                                    filterImages();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<FeedSortMode>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'S�ralama',
                      initialValue: _sortMode,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: FeedSortMode.newest,
                          child: Text('En yeni'),
                        ),
                        PopupMenuItem(
                          value: FeedSortMode.oldest,
                          child: Text('En eski'),
                        ),
                        PopupMenuItem(
                          value: FeedSortMode.nearest,
                          child: Text('En yak�n')),
                      ],
                      onSelected: (mode) {
                        setState(() => _sortMode = mode);
                        if (mode == FeedSortMode.nearest) {
                          _ensureUserLocation();
                        } else {
                          filterImages();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(context),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomButton(
                context,
                'Ana Sayfa',
                Icons.home,
                Theme.of(context).colorScheme.primary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
              ),
              _buildBottomButton(
                context,
                'Market',
                Icons.shopping_cart,
                Theme.of(context).colorScheme.primary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopPage()),
                  );
                },
              ),
              // Messages tab with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildBottomButton(
                    context,
                    'Mesajlar',
                    Icons.chat_bubble,
                    Theme.of(context).colorScheme.primary,
                    () {
                      final user = FirebaseAuth.instance.currentUser;
                      final currentUserUID = user?.uid ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatListPage(currentUserUID: currentUserUID),
                        ),
                      );
                    },
                  ),
                  if (_unreadMessagesCount > 0)
                    _animatedCountBadge(_unreadMessagesCount, right: -4, top: -4),
                ],
              ),
              // Notifications tab with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildBottomButton(
                    context,
                    'Bildirimler',
                    Icons.notifications,
                    Theme.of(context).colorScheme.primary,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationPage()),
                      );
                    },
                  ),
                  if (_unreadNotificationsCount > 0)
                    _animatedCountBadge(_unreadNotificationsCount, right: -4, top: -4),
                ],
              ),
              _buildBottomButton(
                context,
                'Hesap',
                Icons.person,
                Theme.of(context).colorScheme.primary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menu for the search field: save the current filter, jump to a saved one,
  /// or clear everything. Rendered as the field's suffix action.
  void _showSearchMenu() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Refresh the local copy after a mutation so the sheet updates
            // without waiting on the parent's setState.
            final searches = _savedSearches;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark, color: scheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Kay�tl� Aramalar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _hasActiveFilter
                            ? () async {
                                await _saveCurrentSearch();
                                setSheetState(() {});
                              }
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
                if (searches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      'Hen�z kay�tl� araman�z yok. Be�endi�iniz bir aramay� '
                      'veya filtreyi a�a�daki "Kaydet" d��mesiyle saklayabilirsiniz.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searches.length,
                      itemBuilder: (context, index) {
                        final search = searches[index];
                        return ListTile(
                          leading: Icon(Icons.search, color: scheme.primary),
                          title: Text(
                            search.query.isEmpty
                                ? (search.species ?? 'T�m�')
                                : search.query,
                          ),
                          subtitle: Text(_describeSearch(search)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Sil',
                            onPressed: () async {
                              await _deleteSavedSearch(search);
                              setSheetState(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _applySavedSearch(search);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Human-readable summary of a saved search's species + sort.
  String _describeSearch(SavedSearch search) {
    final parts = <String>[
      if (search.species != null) search.species! else 'T�m t�rler',
      switch (search.sortMode) {
        'oldest' => 'en eski',
        'nearest' => 'en yak�n',
        _ => 'en yeni',
      },
    ];
    return parts.join('  •  ');
  }

  Widget _buildBody(BuildContext context) {
    // AnimatedSwitcher cross-fades between the four body states (loading,
    // error, empty, grid) so a refresh or filter change does not hard-swap.
    Widget content;
    if (_isLoading) {
      content = _buildSkeleton(context);
    } else if (_loadFailed) {
      content = _buildStatusView(
        context,
        icon: Icons.cloud_off,
        title: 'Bağlantı sorunu',
        message: 'Petler yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.',
        buttonLabel: 'Tekrar Dene',
        onRetry: _reload,
      );
    } else if (filteredList.isEmpty) {
      final isSearching =
          searchController.text.isNotEmpty || _selectedSpecies != null;
      content = _buildStatusView(
        context,
        icon: isSearching ? Icons.search_off : Icons.pets,
        title: isSearching ? 'Sonuç bulunamadı' : 'Henüz ilan yok',
        message: isSearching
            ? 'Seçili filtrelerle eşleşen bir pet bulunamadı. Aramayı veya tür seçimini değiştirmeyi deneyin.'
            : 'İlk pet ilanını ekleyen siz olun! Sağ üstteki menüden pet ekleyebilirsiniz.',
        // Offer a one-tap reset whenever a filter is actually narrowing the
        // list; otherwise the button would be a no-op and just add noise.
        onSecondary: isSearching ? _clearFilters : null,
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(children: _buildImageRows(context)),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Pure cross-fade: the four states have very different sizes, so a
      // slide would make the layout jump more than it already does.
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<String>(
          'feed-${_isLoading ? 'loading' : _loadFailed ? 'error' : filteredList.isEmpty ? 'empty' : 'grid'}',
        ),
        child: content,
      ),
    );
  }

  /// Pulsing count badge used for unread messages / notifications.
  ///
  /// Replaces four duplicated Containers; the AnimatedSwitcher scales the
  /// number in whenever the count changes instead of hard-swapping the text.
  Widget _animatedCountBadge(int count, {double right = 8, double top = 8}) {
    return Positioned(
      right: right,
      top: top,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Container(
          key: ValueKey<int>(count),
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Pulsing placeholder grid shown while the first page of pets loads.
  Widget _buildSkeleton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(2, (rowIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (colIndex) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1.0),
                      duration: Duration(milliseconds: 700 + (rowIndex * 3 + colIndex) * 120),
                      curve: Curves.easeInOut,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: Column(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: 64,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 36,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatusView(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String? buttonLabel,
    VoidCallback? onRetry,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonLabel ?? 'Tekrar Dene'),
              ),
            ],
            if (onSecondary != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSecondary,
                icon: const Icon(Icons.filter_alt_off),
                label: Text(secondaryLabel ?? 'Filtreleri temizle'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildImageRows(BuildContext context) {
    List<Widget> rows = [];
    for (int i = 0; i < filteredList.length; i += 3) {
      if (i + 3 <= filteredList.length) {
        rows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildImageBox(context, filteredList[i], i),
              _buildImageBox(context, filteredList[i + 1], i + 1),
              _buildImageBox(context, filteredList[i + 2], i + 2),
            ],
          ),
        );
      } else {
        List<Widget> rowChildren = [];
        for (int j = i; j < filteredList.length; j++) {
          rowChildren.add(_buildImageBox(context, filteredList[j], j));
        }
        rows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowChildren,
          ),
        );
      }
      rows.add(const SizedBox(height: 16));
    }
    return rows;
  }

  Widget _buildImageBox(BuildContext context, ImageInfo imageInfo, int index) {
    Widget card = Column(
      children: [
        GestureDetector(
          onTap: () {
            _onInfoButtonPressed(context, imageInfo);
          },
          child: Hero(
            // Shared flight between the feed thumbnail and the detail page's
            // large photo; tag is the pet id, unique per listing.
            tag: 'pet-image-${imageInfo.id}',
            child: SizedBox(
              width: double.infinity,
              height: 120,
              child: AppNetworkImage(
                url: imageInfo.imagePath,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          imageInfo.title,
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
        // Distance badge, shown only when both the viewer and the pet
        // have coordinates. Keeps the card informative without cluttering
        // the common case (no location yet).
        if (_petDistanceKm(imageInfo) != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place,
                    size: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDistance(_petDistanceKm(imageInfo)!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
          onPressed: () {
            _onInfoButtonPressed(context, imageInfo);
          },
          child: const Text(
            'Bilgi Al',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );

    // First appearance only: cascade the cards in on load, but never replay
    // the animation when a filter change remounts the same pet's card.
    if (_animatedIn.add(imageInfo.id)) {
      card = _StaggeredEntrance(index: index, child: card);
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: card,
      ),
    );
  }

  Widget _buildBottomButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _onInfoButtonPressed(BuildContext context, ImageInfo imageInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetDetailPage(
          petId: imageInfo.id,
          imagePath: imageInfo.imagePath,
        ),
      ),
    );
  }
}

/// Fades and slides a feed card in, staggered by [index] so the grid
/// cascades on first load instead of popping in as one block.
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  /// Grid position; drives the per-card delay (capped so deep rows are not
  /// left waiting for seconds).
  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_curve);
    // Cap the cascade at ~10 cards' worth of delay so rows far down the feed
    // are not still invisible after the user has scrolled.
    final delay = Duration(milliseconds: (widget.index * 55).clamp(0, 550));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class ImageInfo implements FeedPetInfo {  @override
  final String id;
  final String imagePath;
  @override
  final String title;
  @override
  final DateTime timestamp;

  /// `Kinds` in Firestore; the species label used by the filter chips.
  @override
  final String kinds;

  /// Human-readable location label written by add_pet_page.dart.
  @override
  final String location;
  @override
  final double? latitude;
  @override
  final double? longitude;

  ImageInfo(
    this.id,
    this.imagePath,
    this.title,
    this.timestamp, {
    this.kinds = '',
    this.location = '',
    this.latitude,
    this.longitude,
  });
}

Future<List<ImageInfo>> fetchImageDataFromFirestore() async {
  List<ImageInfo> imageData = [];
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('pets')
        .orderBy('timestamp', descending: true)
        .get();
    for (final doc in snapshot.docs) {
      // Guard per document: a single malformed pet must not wipe the whole
      // feed, which is what happened when the casts were inside one try block.
      final data = doc.data();
      final imagePath = data['imagePath']?.toString() ?? '';
      final title = data['title']?.toString() ?? '';
      if (imagePath.isEmpty || title.isEmpty) {
        debugPrint('Pet ${doc.id} eksik alan içeriyor, atlandı.');
        continue;
      }
      final rawTimestamp = data['timestamp'];
      final timestamp = rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : DateTime.now();
      // Latitude/longitude are written as doubles by add_pet_page.dart but
      // may arrive as int for documents created by older clients.
      final rawLat = data['latitude'];
      final rawLng = data['longitude'];
      imageData.add(ImageInfo(
        doc.id,
        imagePath,
        title,
        timestamp,
        kinds: data['Kinds']?.toString() ?? '',
        location: data['location']?.toString() ?? '',
        latitude: rawLat is num ? rawLat.toDouble() : null,
        longitude: rawLng is num ? rawLng.toDouble() : null,
      ));
    }
  } catch (e) {
    debugPrint('Resim verileri alınırken hata oluştu: $e');
    // Rethrow so the caller can distinguish "fetch failed" from
    // "fetched successfully but there are no pets yet".
    rethrow;
  }
  return imageData;
}
