import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../stuff/app_network_image.dart';

class ReturnPetPage extends StatefulWidget {
  const ReturnPetPage({super.key});

  @override
  State<ReturnPetPage> createState() => _ReturnPetPageState();
}

class _ReturnPetPageState extends State<ReturnPetPage> {
  List<ImageInfo> deletedImageList = [];

  @override
  void initState() {
    super.initState();
    _fetchDeletedImageDataFromFirestore();
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
                  'Silinen Hayvanlarım',
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
            color: Colors.white,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: deletedImageList.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              const SizedBox(height: 10), // Add spacing between images

              ListTile(
                leading: SizedBox(
                  width: 75,
                  height: 200,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: AppNetworkImage(url:
                      deletedImageList[index].imagePath,
                      fit: BoxFit.cover, // Adjust the image fit
                    ),
                  ),
                ),
                title: Text(deletedImageList[index].title),
                trailing: IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    _showRestoreConfirmationDialog(deletedImageList[index]);
                  },
                ),
              ),
              const SizedBox(height: 20), // Add spacing between images
            ],
          );
        },
      ),
    );
  }

  void _showRestoreConfirmationDialog(ImageInfo imageInfo) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hayvanı Geri Getir'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Bu hayvanı geri getirmek istediğinizden emin misiniz?'),
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
              child: const Text('Geri Getir'),
              onPressed: () async {
                // Async gap sonrasinda BuildContext kullanilmayacagi icin
                // State nesneleri await oncesi yakalanir.
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                final restored = await _restorePet(imageInfo);
                if (!mounted) return;
                if (!restored) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Hayvan geri getirilemedi.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                navigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Restores a pet from `deleted_pets`. Returns false when the restore failed or
/// was refused, so the caller can keep the confirmation dialog open.
Future<bool> _restorePet(ImageInfo imageInfo) async {
    final DateTime deletionDate = imageInfo.timestamp;
    final DateTime currentDate = DateTime.now();
    final Duration difference = currentDate.difference(deletionDate);

    if (difference.inDays <= 7) {
      // Async gap sonrasinda BuildContext kullanilmayacagi icin
      // State nesneleri await oncesi yakalanir.
      final messenger = ScaffoldMessenger.of(context);

      try {
        // Fetch the entire pet data from "deleted_pets" collection
        DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
            .collection('deleted_pets')
            .doc(imageInfo.id)
            .get();

        // Get the entire pet data as a Map
        Map<String, dynamic>? petData =
            docSnapshot.data() as Map<String, dynamic>?;

        if (petData != null) {
          // Add the entire pet data to "pets" collection
          await FirebaseFirestore.instance
              .collection('pets')
              .doc(imageInfo.id)
              .set(petData);
        }

        // Delete the pet from "deleted_pets" collection
        await FirebaseFirestore.instance
            .collection('deleted_pets')
            .doc(imageInfo.id)
            .delete();

        // Update the deletedImageList after restoring the pet
        if (!mounted) return false;
        setState(() {
          deletedImageList.remove(imageInfo);
        });

        messenger.showSnackBar(SnackBar(
          content: Text('${imageInfo.title} adlı hayvan geri getirildi.'),
        ));
        debugPrint('Hayvan geri getirildi: ${imageInfo.title}');
        return true;
      } catch (error) {
        debugPrint('Hayvan geri getirilirken hata oluştu: $error');
        return false;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${imageInfo.title} adlı hayvanı 7 günden daha eski olduğu için geri getiremezsiniz.'),
      ));
      return false;
    }
  }

  Future<void> _fetchDeletedImageDataFromFirestore() async {
    List<ImageInfo> imageData = [];
    String? userUID = getUserUID(); // Kullanıcının UID'sini alın

    if (userUID == null) {
      return; // Eğer UID yoksa, işlemi durdurun
    }

    try {
      // Firestore'dan sadece kullanıcının UID'sine sahip olan belgeleri getirin
      var snapshot = await FirebaseFirestore.instance
          .collection('deleted_pets')
          .where('userUID', isEqualTo: userUID)
          .get();

      for (var doc in snapshot.docs) {
        // Guard per document so one malformed record cannot empty the whole list.
        var data = doc.data();
        String imagePath = data['imagePath']?.toString() ?? '';
        String title = data['title']?.toString() ?? '';
        if (imagePath.isEmpty || title.isEmpty) {
          debugPrint('Silinen pet ${doc.id} eksik alan içeriyor, atlandı.');
          continue;
        }
        var rawTimestamp = data['timestamp'];
        DateTime timestamp =
            rawTimestamp is Timestamp ? rawTimestamp.toDate() : DateTime.now();
        imageData.add(ImageInfo(doc.id, imagePath, title, timestamp));
      }
    } catch (e) {
      debugPrint('Silinen hayvan verileri alınırken hata oluştu: $e');
    }

    setState(() {
      deletedImageList = imageData;
    });
  }
}

class ImageInfo {
  final String id;
  final String imagePath;
  final String title;
  final DateTime timestamp;

  ImageInfo(this.id, this.imagePath, this.title, this.timestamp);
}

String? getUserUID() {
  final User? user = FirebaseAuth.instance.currentUser;
  return user?.uid;
}
