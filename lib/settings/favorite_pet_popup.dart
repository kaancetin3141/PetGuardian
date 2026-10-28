import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/pet_detail_page.dart';
import '../stuff/app_network_image.dart';

class FavoritePetPopup extends StatefulWidget {
  const FavoritePetPopup({super.key});

  @override
  State<FavoritePetPopup> createState() => _FavoritePetPopupState();
}

class _FavoritePetPopupState extends State<FavoritePetPopup> {
  late Future<List<Map<String, dynamic>>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = fetchFavoritePetData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorilerim'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final scheme = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Favoriler yüklenemedi: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(
                      () => _favoritesFuture = fetchFavoritePetData(),
                    ),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final scheme = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz favori hayvanınız yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlan kartlarındaki kalp simgesiyle\nbeğendiğiniz ilanları kaydedin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final pets = snapshot.data!;
          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final petData = pets[index];
              final petId = petData['id']?.toString() ?? '';
              final imagePath = petData['imagePath']?.toString() ?? '';
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: AppNetworkImage(url: imagePath),
                    ),
                  ),
                  title: Text(
                    petData['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    petData['Kinds']?.toString() ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.favorite,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: petId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PetDetailPage(
                                petId: petId,
                                imagePath: imagePath,
                              ),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Loads the signed-in user's favorite pets.
  ///
  /// A favorite document's ID *is* the pet document ID, and it already
  /// denormalises the fields this list renders. The previous implementation
  /// looked for a `randomNumber` field that no writer ever produced
  /// (favorites store `serialNumber`), so every lookup missed and the list
  /// was always empty - and it cost one extra read per favorite.
  Future<List<Map<String, dynamic>>> fetchFavoritePetData() async {
    List<Map<String, dynamic>> favoritePetData = [];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return favoritePetData;

    final QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .get();

    for (final docSnapshot in querySnapshot.docs) {
      final data = docSnapshot.data();

      final title = data['title']?.toString();
      final imagePath = data['imagePath']?.toString();
      if (title == null ||
          title.isEmpty ||
          imagePath == null ||
          imagePath.isEmpty) {
        // Favorites written by an older build stored no fields; fall back to
        // the pet document, which the favorite ID points at directly.
        final petSnapshot = await FirebaseFirestore.instance
            .collection('pets')
            .doc(docSnapshot.id)
            .get();
        if (!petSnapshot.exists) continue;
        final petData = petSnapshot.data();
        if (petData == null) continue;
        favoritePetData.add({...petData, 'id': docSnapshot.id});
        continue;
      }

      favoritePetData.add({...data, 'id': docSnapshot.id});
    }

    return favoritePetData;
  }
}
