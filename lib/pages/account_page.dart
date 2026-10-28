import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petguardian/auth/login_page.dart';
import 'package:petguardian/pages/home_page.dart';
import 'package:petguardian/pages/shop_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petguardian/settings/settings_page.dart';
import 'package:petguardian/settings/add_pet_page.dart';
import '../settings/delete_pet_page.dart';
import '../stuff/image_helper.dart';
import '../services/firebase_messaging_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoggingOut = false;
  dynamic _image;
  Uint8List? _imageBytes;
  String? _imageUrl;
  String? _fullName;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _getUserData();
  }

  // SharedPreferences nesnesini başlatma ve kontrol etme
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs.containsKey('userFullName')) {
      setState(() {
        _fullName = _prefs.getString('userFullName');
      });
    }
    if (_prefs.containsKey('userImageUrl')) {
      setState(() {
        _imageUrl = _prefs.getString('userImageUrl');
      });
    }
  }

  // Verileri ön belleğe alma ve SharedPreferences'a kaydetme
  Future<void> _saveUserDataToCache() async {
    if (_fullName != null) {
      await _prefs.setString('userFullName', _fullName!);
    }
    if (_imageUrl != null) {
      await _prefs.setString('userImageUrl', _imageUrl!);
    }
  }

  Future<void> _getUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userSnapshot.exists) {
        Map<String, dynamic>? userData =
            userSnapshot.data() as Map<String, dynamic>?;

        if (userData != null) {
          setState(() {
            _fullName = userData['fullName'];
            _imageUrl = userData['photoURL'];
          });
          // Verileri ön belleğe al ve SharedPreferences'a kaydet
          await _saveUserDataToCache();
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı verileri alınırken hata oluştu: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await pickImageForPlatform();
      if (result == null) return;

      setState(() {
        if (kIsWeb) {
          _imageBytes = result['bytes'] as Uint8List?;
          _image = null;
        } else {
          _image = result['file'];
          _imageBytes = null;
        }
      });

      String uid = FirebaseAuth.instance.currentUser!.uid;
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(uid)
          .child('avatar.jpg');
      if (kIsWeb && _imageBytes != null) {
        await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else if (_image != null) {
        await ref.putFile(_image!);
      }

      String downloadURL = await ref.getDownloadURL();
      setState(() {
        _imageUrl = downloadURL;
      });

      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(uid);
      await userDocRef
          .set({'photoURL': downloadURL}, SetOptions(merge: true));

      // Verileri ön belleğe al ve SharedPreferences'a kaydet
      await _saveUserDataToCache();
    } catch (e) {
      debugPrint("Profil resmi yüklenirken hata oluştu: $e");
    }
  }

  void _signOut() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Drop the FCM token first, otherwise the next person to sign in on this
      // device keeps receiving the previous user's notifications.
      await FirebaseMessagingService.deleteFCMToken();
    } catch (e) {
      debugPrint('FCM token temizlenirken hata oluştu: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
    await prefs.remove('user_token');

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      debugPrint("Çıkış yaparken hata oluştu: $e");
    }

    if (!mounted) return;
    setState(() {
      _isLoggingOut = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              'Hesabım',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Geri Dön butonunu iptal eder
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundImage: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? NetworkImage(_imageUrl!)
                    : null,
                // A stale cached URL (image deleted from Storage, or offline
                // first load) would otherwise surface as an unhandled
                // exception; drop the reference so the icon placeholder shows.
                onForegroundImageError: (exception, stackTrace) {
                  debugPrint('Profil resmi yüklenemedi: $exception');
                  if (mounted) {
                    setState(() => _imageUrl = null);
                  }
                },
                radius: 100,
                child: Stack(
                  children: [
                    Positioned(
                      right: 25,
                      bottom: -1,
                      child: IconButton(
                        icon: const Icon(Icons.add_a_photo),
                        color: Colors.white,
                        onPressed: _pickImage,
                      ),
                    ),
                    if (_imageUrl == null || _imageUrl!.isEmpty)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 32,
                        child: Icon(
                          Icons.person,
                          size: 150,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _fullName ?? 'İsim Soyisim',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'E-posta Adresi',
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoggingOut ? null : _signOut,
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: _isLoggingOut
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Çıkış Yapılıyor'),
                      ],
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 5),
                        Text('Çıkış Yap'),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPetPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Evcil Hayvan Ekle'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DeletePetPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Evcil Hayvanı Sil veya Düzenle'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_accessibility),
                  SizedBox(width: 8),
                  Text('Profil Ayarları'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.home),
                    SizedBox(width: 8),
                    Text('Ana Sayfa'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_cart),
                    SizedBox(width: 8),
                    Text('Market'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Hesap'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
