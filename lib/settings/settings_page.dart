import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petguardian/pages/account_page.dart';

import './favorite_pet_popup.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              'Ayarlar',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.settings,
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
            ElevatedButton(
              onPressed: () => _changePassword(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Şifreyi Değiştir'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updateUserProfile(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Profil Bilgilerini Güncelle'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _seeFavoritePets(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Favori Evcil Hayvanları Gör'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  void _changePassword(BuildContext context) async {
    String oldPassword = '';
    String newPassword = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Şifreyi Değiştir'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Eski Şifre'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Eski şifre boş olamaz';
                    }
                    // You can add additional validation logic here if needed
                    return null;
                  },
                  onChanged: (value) {
                    oldPassword = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Yeni Şifre'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Yeni şifre boş olamaz';
                    }
                    // You can add additional validation logic here if needed
                    return null;
                  },
                  onChanged: (value) {
                    newPassword = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    final credential = EmailAuthProvider.credential(
                      email: currentUser.email!,
                      password: oldPassword,
                    );

                    // Async gap sonrasinda BuildContext kullanilmayacagi icin
                    // State nesneleri await oncesi yakalanir.
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await currentUser.reauthenticateWithCredential(
                        credential,
                      );
                      await currentUser.updatePassword(newPassword);

                      // No password hash is mirrored into the `users` document:
                      // Firebase Authentication owns the credential, and any
                      // copy of it was readable by every signed-in user.

                      navigator.pop();
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Şifre başarıyla değiştirildi.'),
                      ));
                    } catch (e) {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Eski şifre hatalı.'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Değiştir'),
            ),
          ],
        );
      },
    );
  }
}

// Diğer düğme işlevlerini burada tanımlayın.

void _updateUserProfile(BuildContext context) async {
  final currentUser = FirebaseAuth.instance.currentUser;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser?.uid)
      .get();

  if (userDoc.exists) {
    String currentFullName = userDoc['fullName'] ?? '';
    String currentUsername = userDoc['username'] ?? '';
    String currentPhoneNumber = userDoc['phoneNumber'] ?? '';

    String newFullName = currentFullName;
    String newUsername = currentUsername;
    String newPhoneNumber = currentPhoneNumber;

final formKey = GlobalKey<FormState>();

  if (!context.mounted) return;

  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profil Bilgilerini Güncelle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: currentFullName,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Ad Soyad boş olamaz';
                    }
                    // You can add additional validation logic here if needed
                    return null;
                  },
                  onChanged: (value) {
                    newFullName = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: currentUsername,
                  decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Kullanıcı adı boş olamaz';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    newUsername = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: currentPhoneNumber,
                  keyboardType: TextInputType.phone,
                  maxLength: 11, // Set maximum length
                  decoration: const InputDecoration(labelText: 'Telefon Numarası'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Telefon Numarası boş olamaz';
                    }
                    if (value.length != 11) {
                      return 'Telefon Numarası 11 karakter olmalıdır';
                    }
                    // You can add additional validation logic here if needed
                    return null;
                  },
                  onChanged: (value) {
                    newPhoneNumber = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Async gap sonrasinda BuildContext kullanilmayacagi icin
                  // State nesneleri await oncesi yakalanir.
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    // Firebase Authentication'daki kullanıcı adını güncelleme
                    await currentUser?.updateDisplayName(newFullName);

                    // Firestore'daki kullanıcı belgesini güncelleme
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser?.uid)
                        .update({
                      'fullName': newFullName,
                      'username': newUsername,
                      'phoneNumber': newPhoneNumber,
                    });

                    navigator.pop();
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Profil bilgileri başarıyla güncellendi.'),
                    ));
                  } catch (e) {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('Bir hata oluştu. Profil bilgileri güncellenemedi.'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Güncelle'),
            ),
          ],
        );
      },
    );
  }
}




void _seeFavoritePets(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const FavoritePetPopup()),
  );
}

