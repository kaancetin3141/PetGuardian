import 'package:flutter/material.dart';
import './home_page.dart';
import './shop_page.dart';
import './account_page.dart';
import 'package:url_launcher/url_launcher.dart';


class RentPage extends StatefulWidget {
  const RentPage({super.key});


  @override
  State<RentPage> createState() => _RentPageState();
}
class _RentPageState extends State<RentPage> {
  late  String title;

  bool isBarinakSelected = true;
  bool isBireyselSelected=false;
  bool isVeterinerSelected=false;
  bool isBilgiSelected = false;
  List<Map<String, dynamic>> barinakList = [
    {'Image': 'images/animal_shelter/yedikule.jpg','ad':'\nYedikule Hayvan Barınağı', 'yer': 'İstanbul'},
    {'Image': 'images/animal_shelter/kadikoybarinak.jpg','ad':'\nKadıköy Belediyesi Geçici Hayvan Bakımevi', 'yer': 'İstanbul'},
    {'Image': 'images/animal_shelter/kirik-kuyruk.jpg','ad':'\nKirikkuyruk.com: Sokak Hayvanları Portalı', 'yer': 'İstanbul'},
    {'Image': 'images/animal_shelter/haydos.png','ad':'\nHayvan Dostları Derneği', 'yer': 'Muğla'},
    {'Image': 'images/animal_shelter/ciglirehabilitasyon.jpg','ad':'\nŞişli Belediyesi Hayvan Kısırlaştırma ve \nRehabilitasyon Merkezi ', 'yer': 'İstanbul'},

  ];
  List<Map<String, dynamic>> bireyselList = [
    {'Image': 'images/animal_shelter/image.jpg','ad':' Derya Bilgin', 'yas': '28','deneyim':'\nEvcil Hayvan bakıcılığı konusunda bir deneyime \nsahip değilim.','özet':'\nKöpeklere sevgi konusunda bir zaafım var. \n Önem verdiğim 2 husus olarak bakacağım \nköpeklerin mutlu, iyi bakılmış \nve sağlıklı olmaları\nBakım süreci boyunca sahipleriyle iletişimde\nkalarak birbirimize karşılıklı güveni sağlayarak\nhizmet vermekteyim ','num':'5301341340'},

  ];
  List<Map<String, dynamic>> veterinerList = [

    {'Image': 'images/animal_shelter/firuzkoy.jpg','ad':' Firuzköy Veteriner Kliniği', 'yer': 'İstanbul/Avcılar','adres':'Hasan Önel Cad. No:57','num':'0212 690 30 84'},
    {'Image': 'images/animal_shelter/greenpet.jpg','ad':' Greenpet Veteriner Kliniği', 'yer': 'İstanbul/Bakırköy','adres':'Halkalı Cad. No:50 Yeşilköy','num':'0212 662 22 92'},
    {'Image': 'images/animal_shelter/vetplus.jpg','ad':' Vet Plus Veteriner Kliniği', 'yer': 'İstanbul/Beşiktaş','adres':'Barboros Bulvarı No: 24/1A','num':'0212 216 45 46'},
    {'Image': 'images/animal_shelter/patipata.jpg','ad':' Pati-Pata Veteriner Kliniği', 'yer': 'İstanbul/Beşiktaş','adres':'Etiler, Nispetiye Yıldız Çiçeği','num':'0212 257 00 41'},
    {'Image': 'images/animal_shelter/kanlica.png','ad':' Kanlıca Veteriner Kliniği', 'yer': 'İstanbul/Beykoz','adres':'Kanlıca Mah. Çubuklu Cad. No:28','num':'0216 413 18 82'},
    {'Image': 'images/animal_shelter/animalist.jpg','ad':' Animalist Veteriner Kliniği	', 'yer': 'İstanbul/Ataşehir','adres':'36. Ada Revaklı Çarşı Dükkan No:10	','num':'0216 456 74 52'},
    {'Image': 'images/animal_shelter/dragos.jpg','ad':' Dragos Veteriner Kliniği', 'yer': 'İstanbul/Kartal','adres':'Cevizli Orhantepe Orhangazi No:1','num':'0216 305 60 68'},


  ];


  /// Opens the external caregiver application form.
///
/// launchUrl returns false (or throws) when no handler is available, for
/// example on a device without a browser. Silently logging that made the tap
/// look broken, so the user is told instead.
Future<void> sendFormData() async {
    const formUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLSeoetiYW4oPs4BeMFK347i-6GdioJzmRQBt4sto2ZxRllSKGw/viewform?usp=sf_link';
    final uri = Uri.parse(formUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
      debugPrint('Error launching URL: $uri');
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Başvuru formu açılamadı. Lütfen bağlantıyı tarayıcınızda açmayı '
          'deneyin veya daha sonra tekrar deneyin.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              'PetGuardian',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.pets,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),


      ),

      drawer: Drawer(
        child: ListView(

          padding: EdgeInsets.zero,
          children: <Widget>[

            SizedBox(
              height: 120,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Text(
                  '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            ListTile(
              leading: Icon(Icons.home_filled,color: Theme.of(context).colorScheme.primary),
              title: Text('Barınak',style: TextStyle(fontSize: 17,color: Theme.of(context).colorScheme.onSurfaceVariant )),
              onTap: () {
                setState(() {
                  isBarinakSelected = true;
                  isVeterinerSelected = false;
                  isBilgiSelected = false;
                  isBireyselSelected = false;


                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person,color: Theme.of(context).colorScheme.primary),
              title: Text('Bireysel',style: TextStyle(fontSize: 17,color: Theme.of(context).colorScheme.onSurfaceVariant )),
              onTap: () {
                setState(() {
                  isBireyselSelected = true;
                  isVeterinerSelected = false;
                  isBilgiSelected = false;
                  isBarinakSelected = false;


                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_box_outlined,color: Theme.of(context).colorScheme.primary,),
              title: Text('Bakıcı ol',style: TextStyle(fontSize: 17,color: Theme.of(context).colorScheme.onSurfaceVariant )),
              onTap: () {
                sendFormData();
              },
            ),
            ListTile(
              leading: Icon(Icons.info,color: Theme.of(context).colorScheme.primary),
              title: Text('Bilgi',style: TextStyle(fontSize: 17,color: Theme.of(context).colorScheme.onSurfaceVariant )),
              onTap: () {
                setState(() {
                  isBilgiSelected = true;
                  isVeterinerSelected = false;
                  isBarinakSelected = false;
                  isBireyselSelected=false;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.healing,color: Theme.of(context).colorScheme.primary),
              title: Text('Veteriner',style: TextStyle(fontSize: 17,color: Theme.of(context).colorScheme.onSurfaceVariant )),
              onTap: () {
                setState(() {
                  isVeterinerSelected = true;
                  isBilgiSelected = false;
                  isBarinakSelected = false;

                });
                Navigator.pop(context);
              },

            ),

          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Center(
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(

              children: [
                if (isBarinakSelected )
                  Column(
                    children: [
                      for (var barinak in barinakList)
                        Column(
                          children: [
                            Row(
                              children: [
                                Image.asset(barinak['Image'],height:110,width: 100),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Barınak Adı: ${barinak['ad']}'),
                                    Text('Konumu: ${barinak['yer']}'),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      onPressed: () {
                                        debugPrint('${barinak['ad']} kiralamak için seçildi.');

                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Bakıcı Kiralama İşlemi'),
                                              content: Text(
                                                  '${barinak['ad']} kiralamak için seçildi. \nİlgili kişiler sizinle email yoluyla iletişim kuracaktır.'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context)
                                                        .pop();
                                                  },
                                                  child: const Text('Tamam'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },

                                      icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                                    ),

                                    const SizedBox(height: 5),

                                  ],
                                ),

                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                if (isBireyselSelected )
                  Column(
                    children: [
                      for (var bireysel in bireyselList)
                        Column(
                          children: [
                            Row(
                              children: [
                                Image.asset(bireysel['Image'],height:110,width: 100),

                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Adı Soyadı: ${bireysel['ad']}'),

                                    Text('Yaşı: ${bireysel['yas']}'),
                                    Text('Evcil Hayvan Bakıcılık Deneyimi: ${bireysel['deneyim']}'),
                                    Text('Kısaca Özet: ${bireysel['özet']}'),
                                    Text('Telefon Numarası: ${bireysel['num']}'),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        debugPrint('${bireysel['ad']}  evcil hayvan bakıcılığı için seçildi.');
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Bireysel Evcil Hayvan Bakıcılığı Seçimi'),
                                              content: Text(
                                                  '${bireysel['ad']}  ${bireysel['num']}  evcil hayvan bakıcılığı için seçildi.'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context)
                                                        .pop();
                                                  },
                                                  child: const Text('Tamam'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },


                                      child:  const Icon(Icons.add,color: Colors.red,),

                                    ),


                                    const SizedBox(height: 20,),

                                  ],
                                ),

                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                if (isVeterinerSelected )
                  Column(
                    children: [
                      for (var veteriner in veterinerList)
                        Column(
                          children: [
                            Row(
                              children: [
                                Image.asset(veteriner['Image'],height:110,width: 100),

                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Veteriner Adı: ${veteriner['ad']}'),

                                    Text('Konumu: ${veteriner['yer']}'),
                                    Text('Açık Adres: ${veteriner['adres']}'),


                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        debugPrint('${veteriner['ad']}  ${veteriner['num']} numarası seçildi.');
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Veteriner seçimi'),
                                              content: Text(
                                                  '${veteriner['ad']} ${veteriner['num']} seçildi. '),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context)
                                                        .pop();
                                                  },
                                                  child: const Text('Tamam'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },

                                      icon: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
                                      label: Text('Telefon Numarası: ${veteriner['num']}' ),
                                    ),

                                    const SizedBox(height: 20,),

                                  ],
                                ),

                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                if (isBilgiSelected )
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('images/animal_shelter/catdog.png',height:320,width: 300),
                      const Text('      PetGuardian, hayvanların sağlık ve bakımını takip etmek, sahiplendirme sürecini kolaylaştırmak ve hayvan severlerin ihtiyaçlarını karşılamak için geliştirilen kapsamlı bir uygulamadır. \n Hayvanların benzersiz kimlik numaraları ve profilleri ile birlikte, hayvan barınaklarının ve sahiplenen kişilerin ihtiyaçlarını karşılamak için özel olarak tasarlanmış bir platformdur.'),


                    ],
                  ),

              ],

            ),

          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(

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



    );
  }
}
