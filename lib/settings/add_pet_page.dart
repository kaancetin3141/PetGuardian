import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import './map_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../stuff/image_helper.dart';

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  dynamic _imageFile; // File on mobile
  Uint8List? _imageBytes; // bytes on web
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  LatLng? _selectedLatLng;

  String? _selectedKinds; // tür
  String? _vaccineController; // aşı
  String? _chipController; // çip
  String? _adoptionController; //sahiplendirme
  String? _genderController; // cinsiyet
  String? _selectedLocation; // lokasyon
  String? userUID;
  final firebaseAuth = FirebaseAuth.instance;

  bool _isUploading = false;
  bool _isLoadingMap = false;


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
                  'Evcil Hayvan Ekle',
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),

                    color: Colors.grey[300],
                    border: Border.all(color: Colors.black),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : (_imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.add_a_photo, size: 50)),
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownButtonFormField(
                _selectedKinds,
                'Cins Seç',
                (String? newValue) {
                  setState(() {
                    _selectedKinds = newValue;
                  });
                },
                [
                  'Kedi',
                  'Köpek',
                  'Kuş',
                  'Balık',
                  'Diğer',
                ],
              ),
              const SizedBox(height: 16),
              _buildTitleField('Hayvan İsmi', _titleController),
              const SizedBox(height: 16),
              _buildTitleField('Yaş', _ageController),
              const SizedBox(height: 16),
              _buildDropdownButtonFormField(
                _genderController,
                'Cinsiyet Seç',
                (String? newValue) {
                  setState(() {
                    _genderController = newValue;
                  });
                },
                [
                  'Erkek (Kısır)',
                  'Erkek (Kısır Değil)',
                  'Dişi (Kısır)',
                  'Dişi (Kısır Değil)',
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownButtonFormField(
                _chipController,
                'Cip Durumu',
                (String? newValue) {
                  setState(() {
                    _chipController = newValue;
                  });
                },
                [
                  'Çip Takılı',
                  'Çip Takılı değil',
                  'Bilinmiyor',
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownButtonFormField(
                _vaccineController,
                'Aşı Durumunu Seç',
                (String? newValue) {
                  setState(() {
                    _vaccineController = newValue;
                  });
                },
                [
                  'Aşıları Tam',
                  'Aşıları Eksik',
                  'Bilinmiyor',
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownButtonFormField(
                _adoptionController,
                'Sahiplendirme Durumunu Seç',
                (String? newValue) {
                  setState(() {
                    _adoptionController = newValue;
                  });
                },
                [
                  'Daha Önce Sahiplendirildi',
                  'Daha Önce Sahiplendirilmedi',
                  'Bilinmiyor',
                ],
              ),
              const SizedBox(height: 16),
              _buildTitleField('Hayvanın Türü', _typeController),
              const SizedBox(height: 16),
              _buildTitleFieldPhone(
                  'Telefon Numarası (11 Rakam)', _phoneNumberController),
              SizedBox(height: 16),
              _buildTitleField('Not', _noteController),
              SizedBox(height: 16),
              _buildLocationButton(), // Konum butonu eklendi
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                onPressed: _isUploading ? null : _uploadPetData,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(String labelText, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildDropdownButtonFormField(
    String? value,
    String labelText,
    void Function(String?) onChanged,
    List<String> items,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: items.map((value) => _buildDropdownMenuItem(value)).toList(),
      decoration: InputDecoration(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black),
        ),
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownMenuItem(String value) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(value, style: const TextStyle(color: Colors.black)),
    );
  }

  Widget _buildTitleFieldPhone(
      String labelText, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        LengthLimitingTextInputFormatter(11),
      ],
      decoration: InputDecoration(
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _pickImage() async {
    try {
      final result = await pickImageForPlatform();
      if (result == null) return;
      setState(() {
        if (kIsWeb) {
          _imageBytes = result['bytes'] as Uint8List?;
          _imageFile = null;
        } else {
          _imageFile = result['file'];
          _imageBytes = null;
        }
      });
    } catch (e) {
      debugPrint('Resim seçerken hata oluştu: $e');
    }
  }

  void _selectLocation() async {
    // Check if location permission has been granted
    var status = await Permission.location.status;

    if (status.isDenied) {
      // If permission is denied, request it
      status = await Permission.location.request();
      if (status.isDenied) {
        // Permission still not granted, show a message or take appropriate action
        debugPrint('Location permission is required to access the map.');
        return;
      }
    }
    setState(() {
      _isLoadingMap = true;
    });

    final position = await Geolocator.getCurrentPosition();
    final initialLocation = LatLng(position.latitude, position.longitude);

    if (!mounted) return;

    final selectedLatLng = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(initialLocation: initialLocation),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isLoadingMap = false;
    });

    if (selectedLatLng != null) {
      setState(() {
        _selectedLatLng = selectedLatLng;
        _selectedLocation =
            '${_selectedLatLng!.latitude}, ${_selectedLatLng!.longitude}';
      });
    }
  }

  Future<void> _uploadPetData() async {
    setState(() {
      _isUploading = true;
    });

    // Web keeps the picked image in _imageBytes, mobile in _imageFile, so accept either.
    if ((_imageFile == null && _imageBytes == null) ||
        _titleController.text.isEmpty ||
        _selectedKinds == null ||
        _ageController.text.isEmpty ||
        _genderController == null ||
        _typeController.text.isEmpty ||
        _noteController.text.isEmpty ||
        _vaccineController == null ||
        _adoptionController == null ||
        _chipController == null ||
        _phoneNumberController.text.isEmpty ||
        _selectedLocation == null) {
      debugPrint('Tüm alanlar doldurulmalıdır.');
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // Telefon numarasını doğrulama
    final phoneNumber = _phoneNumberController.text;
    if (phoneNumber.length != 11 ||
        !phoneNumber.contains(RegExp(r'^\d{11}$'))) {
      debugPrint('Geçerli bir 11 haneli telefon numarası girmelisiniz.');
      setState(() {
        _isUploading = false;
      });
      return;
    }

    try {
      // Firebase Storage'a resim yükleme
      final randomNumber = _generateRandomNumber();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('pets_images')
          .child('$randomNumber.jpg'); // Resim adı olarak randomNumber kullanıldı
      if (kIsWeb && _imageBytes != null) {
        await storageRef.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else if (_imageFile != null) {
        await storageRef.putFile(_imageFile!);
      }

      // Firestore'a hayvan bilgilerini kaydetme
      final imageUrl = await storageRef.getDownloadURL();
      final user = FirebaseAuth.instance.currentUser;

      final timestamp = DateTime.now();
      final addedBy = user?.email ?? '';

      String? fullName;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        fullName = userDoc['fullName'];
      }

      String? ipAddress;
      try {
        final response = await http
            .get(Uri.parse('https://api.ipify.org?format=json'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          ipAddress = data['ip']?.toString();
        }
      } catch (e) {
        debugPrint('IP adresi alınırken hata oluştu: $e');
      }

      final petData = {
        'serialNumber': randomNumber,
        'imagePath': imageUrl,
        'title': _titleController.text,
        'Kinds': _selectedKinds,
        'age': _ageController.text,
        'gender': _genderController,
        'vaccine': _vaccineController,
        'adoption': _adoptionController,
        'chip': _chipController,
        'type': _typeController.text,
        'note': _noteController.text,
        'email': user?.email ?? '',
        'phone': phoneNumber,
        'timestamp': timestamp.toUtc(),
        'addedBy': addedBy,
        'userUID': user?.uid,
        'fullName': fullName ?? '',
        'ipAddress': ipAddress ?? '',
        'location': _selectedLocation ?? '', // Seçilen konumu ekle
      };

      if (_selectedLatLng != null) {
        petData['geopoint'] = GeoPoint(
            _selectedLatLng!.latitude, _selectedLatLng!.longitude);

        final placemark = await Geocoding().placemarkFromCoordinates(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        );

        if (placemark.isNotEmpty) {
          final firstPlacemark = placemark.first;
          petData['placemark'] = {
            'latitude': _selectedLatLng!.latitude,
            'longitude': _selectedLatLng!.longitude,
            'name': firstPlacemark.name,
            'thoroughfare': firstPlacemark.thoroughfare,
            'subThoroughfare': firstPlacemark.subThoroughfare,
            'locality': firstPlacemark.locality,
            'subLocality': firstPlacemark.subLocality,
            'administrativeArea': firstPlacemark.administrativeArea,
            'postalCode': firstPlacemark.postalCode,
            'country': firstPlacemark.country,
          };
        }
      }
      // hayvanı firebaseye kaydet
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(randomNumber)
          .set(petData);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Hayvan bilgileri kaydedilirken hata oluştu: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hayvan kaydedilemedi. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _generateRandomNumber() {
    final random = Random.secure();
    final values = List<int>.generate(11, (_) => random.nextInt(10));
    return values.join();
  }

  Widget _buildLocationButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(249, 238, 28, 98),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: _isUploading || _isLoadingMap ? null : _selectLocation,
      icon: const Icon(Icons.location_on, color: Colors.white),
      label: _isLoadingMap
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : const Text(
        'Konum Seç',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

}
