import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../stuff/app_network_image.dart';

class FavoritePetPopup extends StatelessWidget {
  const FavoritePetPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Pets'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchFavoritePetData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No favorite pets found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var petData = snapshot.data![index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FavoritePetDetailPage(petData: petData),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: AppNetworkImage(url: petData['imagePath']?.toString() ?? ''),
                      ),
                      title: Text(petData['title'] ?? 'Unknown Title'),
                      // Display other pet information as needed
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  /// Loads the signed-in user's favorite pets.
///
/// A favorite document's ID *is* the pet document ID, and it already
/// denormalises the fields this list renders. The previous implementation looked
/// for a `randomNumber` field that no writer ever produced (favorites store
/// `serialNumber`), so every lookup missed and the list was always empty - and it
/// cost one extra read per favorite.
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
    if (title == null || title.isEmpty || imagePath == null || imagePath.isEmpty) {
      // Favorites written by an older build stored no fields; fall back to the
      // pet document, which the favorite ID points at directly.
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
/// Lightweight detail view for a favorite row.
///
/// Deliberately named apart from the full `PetDetailPage` in
/// lib/pages/pet_detail_page.dart: the two screens take different inputs
/// (denormalised favorite snapshot vs pet id) and sharing the name made
/// navigation targets ambiguous when reading call sites.
class FavoritePetDetailPage extends StatelessWidget {
  final Map<String, dynamic> petData;

  const FavoritePetDetailPage({super.key, required this.petData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(petData['title'] ?? 'Pet Detail'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: AppNetworkImage(url: petData['imagePath']?.toString() ?? ''),
          ),
          const SizedBox(height: 20),
          Text('Title: ${petData['title'] ?? 'Unknown Title'}'),
          // Display other pet information as needed
        ],
      ),
    );
  }
}
