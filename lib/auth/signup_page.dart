import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import './login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _sozlesmeAccepted = false;
  bool _kayitOlButtonEnabled = false;
  bool _isLoading = false;
  bool obscurePassword = true;

  final formKey = GlobalKey<FormState>();
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  String displayName = '';
  String password = '';
  String email = '';
  String phoneNumber = '';
  String fullName = '';
  final timestamp = DateTime.now();

  void _onaylandi() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kişisel Verilerin İşlenmesine İlişkin Aydınlatma Metni'),
          content: const SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  '\n    Veri Sorumlusu D-Market Elektronik Hizmetler ve Ticaret Anonim Şirketi (“PetGuardian” veya “Şirket”)'
                  '\n PetGuardian olarak 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) ile ilgili mevzuat ve yasal düzenlemelerden kaynaklanan faaliyetlerimiz çerçevesinde kişisel verilerinizin işlenmesi, saklanması ve aktarılmasına ilişkin veri sahibi ilgili kişileri aydınlatmak amacıyla işbu Kişisel Verilerin İşlenmesi Aydınlatma Metni’ni (“Aydınlatma Metni”) hazırladık.'
                  '\n\n  Bunlara ek olarak internet sitemizi, mobil sitemizi ve/veya mobil uygulamamızı ziyaret etmeniz durumunda kullanılan çerez ve SDK’lar hakkında ayrıntılı bilgiler Çerez Politikası’nda yer almaktadır. Bunlar aracılığıyla işlenen kişisel veriler ise bu Aydınlatma Metni’nde açıklanmaktadır.'
                  '\n\n  Aydınlatma Metni, PetGuardian tarafından yayımlandığı tarih itibariyle geçerli olacaktır. PetGuardian, Aydınlatma Metni’nde gerekli olduğu takdirde her zaman değişiklik yapabilir. Yapılacak değişiklikler, Aydınlatma Metni’nin https://www.PetGuardian.com/kisisel-verilerin-korunmasi adresinde yayımlanmasıyla birlikte derhal geçerlilik kazanır.'
                  '\n\n   Kişisel Verilerin Saklanması, Haklarınız ve Başvuru'
                  '\n Saklama ve İmha'
                  '\n Şirketimiz kişisel verileri saklama ve silme işlemleri için bir Saklama ve İmha Politikası oluşturmuştur. Kişisel verilerinize ilişkin saklama ve imha işlemleri bu politika kapsamında gerçekleştirilmektedir. Buna göre KVKK’da veya ilgili kanunlar ile sair ilgili mevzuatta verinin saklanması için bir süre belirlenmişse, söz konusu veri en az bu süre kadar saklanmak zorundadır'
                  '\n\n   Olası bir mahkeme talebinin veya kanunla yetkili kılınmış bir idari merciinin ilgili veriye ilişkin talebinin tarafımıza geç ulaşması veya tarafı olabileceğimiz bir ihtilafın meydana gelmesi gibi ihtimaller gözetilerek, verilerinizin saklanması için mevzuatta öngörülen sürelere 6 ay ila 1 yıl arası bir süre eklenerek verilerin saklama süresi belirlenmekte ve belirlenen sürenin sonunda söz konusu veriler silinmekte, yok edilmekte veya anonimleştirilmektedir.'
                  '\n\n   Mevzuatta işlediğimiz verinin saklanma süresine yönelik bir süre öngörülmemiş ise aramızdaki ilişkinin gereği olarak olası uyuşmazlıklar da göz önüne alınarak hukuki ilişkimizin sona ermesinden itibaren 10 yıllık dava zamanaşımı süresinin geçmesiyle verileriniz herhangi bir talebinize gerek olmadan silinir, yok edilir veya anonim hale getirilir.'
                  '\n\n   Kişisel verilerin işleme şartlarının tamamı ortadan kalkmış ya da tarafımızca beyan edilen veya mevzuat kapsamında belirlenen saklama süresi dolmuş ise verileriniz, ilk periyodik imha tarihinde veya en geç 6 ay içerisinde re’sen silinir, yok edilir veya anonim hale getirilir. Geçerli bir sebep ile verilerinizin silinmesine dair talepte bulunmanız halinde ise verileriniz yasal olarak mümkün olduğu nispette en geç 30 gün içerisinde silinir. Saklama süresi mevzuatta belirlenmiş verilerinizin öngörülen sürelerden önce silinmesini veya imha edilmesini talep etmeniz halinde söz konusu talebiniz gerçekleştirilemeyecektir'
                  '\n\n   Haklarınız'
                  '\n KVKK ve ilgili mevzuat kapsamında kişisel verilerinize ilişkin olarak;'
                  '\n Kişisel verilerinizin işlenip işlenmediğini öğrenme,'
                  '\n Kişisel verileriniz işlenmişse buna ilişkin bilgi talep etme,'
                  '\n Kişisel verilerin işlenme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme,'
                  '\n Kişisel verilerinizin aktarıldığı üçüncü kişileri bilme,'
                  '\n Kişisel verilerinizin eksik veya yanlış işlenmiş olması halinde bunların düzeltilmesini isteme,'
                  '\n KVKK mevzuatında öngörülen şartlar çerçevesinde kişisel verilerinizin silinmesini veya yok edilmesini isteme,'
                  '\n Eksik veya yanlış verilerin düzeltilmesi ile kişisel verilerinizin silinmesi veya yok edilmesini talep ettiğinizde, bu durumun kişisel verilerinizi aktardığımız üçüncü kişilere bildirilmesini isteme,'
                  '\n İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi suretiyle kişinin kendisi aleyhine bir sonucun ortaya çıkmasına itiraz etme ve'
                  '\n Kişisel verilerin kanuna aykırı olarak işlenmesi sebebiyle zarara uğramanız halinde bu zararın giderilmesini talep etme'
                  ' haklarına sahipsiniz'
                  '\n\n   Başvuru'
                  '\n Kişisel verileriniz ile ilgili başvuru ve taleplerinizi dilerseniz İlgili Kişi Başvuru Formu’nu kullanarak;'
                  '\n Geçerli bir kimlik belgesi ile birlikte Şirketimize bizzat başvurarak,'
                  '\n Şirketimize daha önce bildirilen ve sistemimizde kayıtlı bulunan elektronik posta adresinizden kvk@PetGuardian.com adresimize göndererek, '
                  '\n PetGuardian’ya iletebilirsiniz.'
                  '\n\n   Veri Sorumlusuna Başvuru Usul ve Esasları Hakkında Tebliğ uyarınca ilgili kişilerin bu başvurularında ad – soyad, başvuru yazılı ise imza, T.C. kimlik numarası (başvuruda bulunan kişinin yabancı olması halinde pasaport numarası), tebligata esas yerleşim yeri veya iş yeri adresi, varsa bildirime esas elektronik posta adresi, telefon numarası ve faks numarası ile talep konusuna dair bilgilerin bulunması zorunludur.'
                  '\n\n   Veri sahibi ilgili kişi, yukarıda belirtilen hakları kullanmak için yapacağı ve kullanmayı talep ettiği hakka ilişkin açıklamaları içeren başvuruda talep edilen hususu açık ve anlaşılır şekilde belirtilmelidir. Başvuruya ilişkin bilgi ve belgelerin başvuruya eklenmesi gerekmektedir.'
                  '\n\n   Talep konusunun başvuranın şahsı ile ilgili olması gerekmekle birlikte, başkası adına hareket ediliyor ise başvuruyu yapanın bu konuda özel olarak yetkili olması ve bu yetkinin belgelendirilmesi (özel vekâletname) gerekmektedir. Ayrıca başvurunun kimlik ve adres bilgilerini içermesi ve başvuruya kimliği doğrulayıcı belgelerin eklenmesi gerekmektedir.'
                  '\n\n   Yetkisiz üçüncü kişilerin başkası adına yaptığı talepler değerlendirmeye alınmayacaktır.'
                  '\n\n   Kişisel verilerinize ilişkin hak talepleriniz değerlendirilerek, Şirketimize ulaştığı tarihten itibaren en geç 30 gün içerisinde cevaplanır. Başvurunuzun olumsuz değerlendirilmesi halinde, gerekçeli ret sebepleri başvuruda belirttiğiniz adrese elektronik posta veya posta yolu başta olmak üzere eğer mümkünse talebin yapıldığı usul vasıtasıyla size iletilir.'
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
              ),
              onPressed: () {
                Navigator.of(context).pop();

                setState(() {
                  _sozlesmeAccepted = true;
                  _kayitOlButtonEnabled = true;
                });
              },
              child: const Text(' Okudum, onaylıyorum.'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _kayitOl() async {
    if (!_sozlesmeAccepted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Uyarı'),
            content: const Text('Devam etmek için sözleşmeyi kabul etmeniz gerekiyor.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      // Verification mail is best-effort: the account above is already
      // created, so a failure here must not be reported as "registration
      // failed" (the user would retry and hit email-already-in-use).
      try {
        await userCredential.user!.sendEmailVerification();
      } catch (e) {
        debugPrint('Doğrulama e-postası gönderilemedi: $e');
      }

      Position? userLocation;
      try {
        userLocation = await Geolocator.getCurrentPosition();
      } catch (e) {
        userLocation = null;
        debugPrint('Konum bilgisini alırken hata oluştu: $e');
      }

      await firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email.trim().toLowerCase(),
        'username': displayName.trim(),
        'acceptedTerms': _sozlesmeAccepted,
        'phoneNumber': phoneNumber.trim(),
        'userUID': userCredential.user!.uid,
        'fullName': fullName.trim(),
        'createdAt': timestamp.toUtc(),
        'role': 'customer',
        'emailVerified': false,
        'location': userLocation != null
            ? GeoPoint(userLocation.latitude, userLocation.longitude)
            : null,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      _showVerificationDialog();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'Kayıt olma sırasında bir hata oluştu.';
      if (e.code == 'email-already-in-use') {
        message = 'Bu e-posta zaten kayıtlı.';
      } else if (e.code == 'weak-password') {
        message = 'Şifre yeterince güçlü değil.';
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Hata'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    } catch (e, stackTrace) {
      if (!mounted) {
        return;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Hata'),
            content: const Text('Kayıt olma sırasında bir hata oluştu. Lütfen tekrar deneyin.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );

      debugPrint('Hata Ayrıntıları: $e\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Başarılı Kayıt'),
          content: const Text('Giriş yapmak için lütfen e-postanıza gönderilen mailden hesabınızı doğrulayın.'),
          actions: [
            TextButton(
              child: const Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.only(left: 55.0, right: 50.0),
        child: Center(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
                    Text(
                      'PetGuardian',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Icon(Icons.pets, color: Theme.of(context).colorScheme.primary)
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary),
                    Text(
                      'BİLGİLERİNİZİ GİRİNİZ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'E-posta boş bırakılamaz.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      email = value!.trim();
                    },
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      labelText: 'E-posta',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kullanıcı adı boş bırakılamaz.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      displayName = value!.trim();
                    },
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      labelText: 'Kullanıcı Adı',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
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
                      if (value == null || value.isEmpty) {
                        return 'Şifre boş bırakılamaz!';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      password = value!;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'İsim ve soyisim boş bırakılamaz.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      fullName = value!.trim();
                    },
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      labelText: 'İsim Soyisim',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Telefon numarası boş bırakılamaz.';
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'Sadece rakamlar girilmelidir.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      phoneNumber = value!.trim();
                    },
                    decoration: InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      labelText: 'Telefon Numarası',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _sozlesmeAccepted,
                      onChanged: (value) {
                        _onaylandi();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      'Sözleşmeyi okuyup, Kabul ediyorum.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Stack(
                  children: [
                    ElevatedButton(
                      onPressed: _kayitOlButtonEnabled && !_isLoading ? _kayitOl : null,
                      style: ElevatedButton.styleFrom(
                        shadowColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        'KAYIT OL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: Text(
                    'GERİ DÖN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
