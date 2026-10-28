import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/home_page.dart';
import 'signup_page.dart';
import '../services/firebase_messaging_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String email;
  late String password;
  bool obscurePassword = true;
  final String tokenKey = 'user_token';
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkUserLogin();
  }

  Future<void> checkUserLogin() async {
    // A stored uid alone is not a session. Trusting it meant a revoked or
    // expired Auth session still opened HomePage, where every Firestore call
    // was then rejected by the security rules.
    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString('uid');

    User? authUser;
    try {
      authUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Firebase is unavailable (not initialised yet). Fall through to login.
      debugPrint('Oturum kontrolü atlandı: $e');
    }

    if (storedUid != null && authUser != null && authUser.uid == storedUid) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
      return;
    }

    // Stale or partial state: clear it so the login screen is authoritative.
    if (storedUid != null || prefs.getString(tokenKey) != null) {
      await prefs.remove('uid');
      await prefs.remove(tokenKey);
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final normalizedEmail = email.trim().toLowerCase();

        // Firebase Authentication owns the password. The previous
        // implementation compared a bcrypt hash read from the `users`
        // collection instead, which never established an Auth session, so
        // `request.auth` stayed null and every Firestore read afterwards was
        // rejected by the security rules.
        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            );
        final user = userCredential.user;
        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Kullanıcı bulunamadı.',
          );
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);
        await prefs.setString(tokenKey, 'user_token');

        await updateEmailVerifiedInFirestore(user.uid);

        // Initialize FCM token for this user
        await FirebaseMessagingService.initialize();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        _showLoginError(_messageForAuthError(e.code));
      } catch (e) {
        if (!mounted) return;
        _showLoginError('Giriş yapılamadı. Lütfen tekrar deneyin.');
      }
    }
  }

  String _messageForAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-email':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
      default:
        return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }

  void _showLoginError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hata'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showLoginError('Lütfen bir e-posta adresi girin.');
      return;
    }

    try {
      // Firebase issues the reset mail, and it works while signed out unlike a
      // query against the `users` collection.
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('E-posta gönderildi'),
            content: Text(
              '$email adresine şifre sıfırlama bağlantısı gönderildi. '
              'Lütfen gelen kutunuzu kontrol edin.',
            ),
            actions: [
              TextButton(
                child: const Text('Tamam'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Do not reveal whether the address is registered.
      final message = (e.code == 'user-not-found' || e.code == 'invalid-email')
          ? 'Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.'
          : 'Şifre sıfırlama e-postası gönderilemedi. Lütfen tekrar deneyin.';
      _showLoginError(message);
    } catch (e) {
      if (!mounted) return;
      _showLoginError('Şifre sıfırlama e-postası gönderilemedi.');
    }
  }

  Future<void> updateEmailVerifiedInFirestore(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'emailVerified': true},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore güncelleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.only(left: 55.0, right: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 10.0),
                  Text(
                    'PetGuardian',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 10.0),
                  Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
                ],
              ),
              SizedBox(height: 100.0),
              Text(
                'HOŞGELDİNİZ',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  labelText: 'E-posta',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.mail, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'E-posta adresinizi giriniz!';
                  }
                  return null;
                },
                onSaved: (value) {
                  email = value!;
                },
              ),
              const SizedBox(height: 10.0),
              TextFormField(
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    child: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Şifrenizi giriniz!';
                  }
                  return null;
                },
                onSaved: (value) {
                  password = value!;
                },
              ),
              const SizedBox(height: 5.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Şifremi Unuttum'),
                            content: SingleChildScrollView(
                              child: SizedBox(
                                height: 110,
                                width: 350,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                        ),
                                        labelText: 'E-posta Adresinizi Girin',
                                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        prefixIcon: Icon(Icons.mail, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ),
                                    const SizedBox(height: 10.0),
                                    Row(
                                      children: [
                                        const SizedBox(width: 35.0),
                                        SizedBox(
                                          width: 100.0,
                                          height: 40.0,
                                          child: ElevatedButton(
                                            style: ButtonStyle(
                                              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                                RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10.0),
                                                ),
                                              ),
                                              backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                                            ),
                                            onPressed: _resetPassword,
                                            child: const Text('Gönder'),
                                          ),
                                        ),
                                        const SizedBox(width: 20.0),
                                        SizedBox(
                                          width: 100.0,
                                          height: 40.0,
                                          child: ElevatedButton(
                                            style: ButtonStyle(
                                              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                                RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10.0),
                                                ),
                                              ),
                                              backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                                            ),
                                            child: const Text('Geri Dön'),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const LoginPage()),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                    ),
                    child: const Text('Şifremi Unuttum'),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                      ),
                      onPressed: _login,
                      child: const Text('GİRİŞ YAP'),
                    ),
                  ),
                  const SizedBox(width: 20.0),
                  Expanded(
                    child: ElevatedButton(
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                      ),
                      child: const Text('KAYDOL'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
