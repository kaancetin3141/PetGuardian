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
import '../stuff/app_network_image.dart';
import '../stuff/feed_filter.dart';

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

  @override
  void initState() {
    super.initState();
    _reload();
    searchController.addListener(filterImages);
    _listenToUnreadCounts();
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
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotificationsCount > 99 ? '99+' : _unreadNotificationsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
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
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadMessagesCount > 99 ? '99+' : _unreadMessagesCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
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
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Aramay� temizle',
                            onPressed: () => searchController.clear(),
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
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadMessagesCount > 99 ? '99+' : _unreadMessagesCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
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
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          _unreadNotificationsCount > 99 ? '99+' : _unreadNotificationsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
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

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton(context);
    }
    if (_loadFailed) {
      return _buildStatusView(
        context,
        icon: Icons.cloud_off,
        title: 'Bağlantı sorunu',
        message: 'Petler yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.',
        buttonLabel: 'Tekrar Dene',
        onRetry: _reload,
      );
    }
    if (filteredList.isEmpty) {
      final isSearching =
          searchController.text.isNotEmpty || _selectedSpecies != null;
      return _buildStatusView(
        context,
        icon: isSearching ? Icons.search_off : Icons.pets,
        title: isSearching ? 'Sonuç bulunamadı' : 'Henüz ilan yok',
        message: isSearching
            ? 'Seçili filtrelerle eşleşen bir pet bulunamadı. Aramayı veya tür seçimini değiştirmeyi deneyin.'
            : 'İlk pet ilanını ekleyen siz olun! Sağ üstteki menüden pet ekleyebilirsiniz.',
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: _buildImageRows(context)),
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
              _buildImageBox(context, filteredList[i]),
              _buildImageBox(context, filteredList[i + 1]),
              _buildImageBox(context, filteredList[i + 2]),
            ],
          ),
        );
      } else {
        List<Widget> rowChildren = [];
        for (int j = i; j < filteredList.length; j++) {
          rowChildren.add(_buildImageBox(context, filteredList[j]));
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

  Widget _buildImageBox(BuildContext context, ImageInfo imageInfo) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                _onInfoButtonPressed(context, imageInfo);
              },
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: AppNetworkImage(
                  url: imageInfo.imagePath,
                  fit: BoxFit.fitHeight,
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
        ),
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

class ImageInfo implements FeedPetInfo {
  @override
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
