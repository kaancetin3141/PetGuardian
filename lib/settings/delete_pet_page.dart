import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './return_pet_page.dart';
import './update_pet_information.dart'; // Import the ReturnPetPage.dart file
import '../stuff/app_network_image.dart';

class DeletePetPage extends StatefulWidget {
  const DeletePetPage({super.key});

  @override
  State<DeletePetPage> createState() => _DeletePetPageState();
}

class _DeletePetPageState extends State<DeletePetPage> {
  List<ImageInfo> userImageList = [];

  @override
  void initState() {
    super.initState();
    fetchUserImageDataFromFirestore().then((data) {
      setState(() {
        userImageList = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pets,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Sahiplendirme Listem',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.pets,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: userImageList.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              const SizedBox(height: 10), // Set the desired spacing between images

              ListTile(
                leading: SizedBox(
                  width: 75, // Set the desired width here
                  height: 200, // Set the desired height here
                  child: AspectRatio(
                    aspectRatio:
                        1.0, // Make sure the aspect ratio is 1:1 for a square
                    child: AppNetworkImage(url:
                      userImageList[index].imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(userImageList[index].title),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _navigateToUpdatePetPage(userImageList[index]);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _showDeleteConfirmationDialog(userImageList[index]);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // Set the desired spacing between images
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 10),
          child: ElevatedButton(
            onPressed: () {
              // Navigate to the ReturnPetPage
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReturnPetPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Silinen Hayvanlar'),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(ImageInfo imageInfo) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hayvanı Sil'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Bu hayvanı silmek istediğinizden emin misiniz?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Vazgeç'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sil'),
              onPressed: () async {
                // Async gap sonrasinda BuildContext kullanilmayacagi icin
                // State nesneleri await oncesi yakalanir.
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                // Firestore'dan hayvanı sil
                final deleted = await _deletePet(imageInfo);
                if (!mounted) return;
                if (!deleted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Hayvan silinemedi. Lütfen tekrar deneyin.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Güncellenmiş kullanıcı hayvanlarını getir
                await fetchUserImageDataFromFirestore().then((data) {
                  if (!mounted) return;
                  setState(() {
                    userImageList = data;
                  });
                });
                navigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToUpdatePetPage(ImageInfo imageInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdatePetInformation(
          randomNumber: imageInfo.id,
        ),
      ),
    );
  }
}

/// Moves a pet into `deleted_pets` and removes it from `pets`.
/// Returns false when the move failed, so the caller can keep the dialog open
/// and tell the user instead of silently dropping the pet from the list.
Future<bool> _deletePet(ImageInfo imageInfo) async {
  try {
    // Firestore'dan hayvanı al
    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .doc(imageInfo.id)
        .get();

    // Hayvanı "deleted_pets" koleksiyonuna taşı (kopyala)
    Map<String, dynamic>? petData = docSnapshot.data() as Map<String, dynamic>?;
    if (petData != null) {
      await FirebaseFirestore.instance
          .collection('deleted_pets')
          .doc(imageInfo.id)
          .set(petData);
    }

    // Hayvanı "pets" koleksiyonundan sil
    await FirebaseFirestore.instance
        .collection('pets')
        .doc(imageInfo.id)
        .delete();

    debugPrint(
        'Hayvan silindi ve "deleted_pets" koleksiyonuna taşındı: ${imageInfo.title}');
    return true;
  } catch (e) {
    debugPrint('Hayvan silinirken hata oluştu: $e');
    return false;
  }
}

Future<List<ImageInfo>> fetchUserImageDataFromFirestore() async {
  List<ImageInfo> imageData = [];
  try {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('email', isEqualTo: user.email)
          .get();
      for (var doc in snapshot.docs) {
        // Guard per document so one malformed pet cannot empty the whole list.
        var data = doc.data();
        String imagePath = data['imagePath']?.toString() ?? '';
        String title = data['title']?.toString() ?? '';
        if (imagePath.isEmpty || title.isEmpty) {
          debugPrint('Pet ${doc.id} eksik alan içeriyor, atlandı.');
          continue;
        }
        var rawTimestamp = data['timestamp'];
        DateTime timestamp =
            rawTimestamp is Timestamp ? rawTimestamp.toDate() : DateTime.now();
        imageData.add(ImageInfo(doc.id, imagePath, title, timestamp));
      }
    }
  } catch (e) {
    debugPrint('Kullanıcının hayvan verileri alınırken hata oluştu: $e');
  }
  return imageData;
}

class ImageInfo {
  final String id;
  final String imagePath;
  final String title;
  final DateTime timestamp;

  ImageInfo(this.id, this.imagePath, this.title, this.timestamp);
}
