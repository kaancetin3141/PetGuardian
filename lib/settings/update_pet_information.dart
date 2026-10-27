import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:petguardian/settings/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../stuff/image_helper.dart';
import '../stuff/app_network_image.dart';

class UpdatePetInformation extends StatefulWidget {
  final String randomNumber;

  const UpdatePetInformation({super.key, required this.randomNumber});

  @override
  State<UpdatePetInformation> createState() => _UpdatePetInformationState();
}

class _UpdatePetInformationState extends State<UpdatePetInformation> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String? _selectedKinds;
  String? _vaccineController;
  String? _chipController;
  String? _adoptionController;
  String? _genderController;
  String? _selectedLocation;
  String? userUID;
  String? _serialNumber;
  LatLng? _selectedLatLng;
  Map? _placemark;

  bool _isUpdating = false;
  bool _isLoadingMap = false;

  dynamic _imageFile;
  Uint8List? _imageBytes;
  String? _imageUrl;


  @override
  void initState() {
    super.initState();
    _fetchPetData();
  }
// pet datasını çekiyor
  Future<void> _fetchPetData() async {
    try {
      final petDoc = await FirebaseFirestore.instance
          .collection('pets')
          .doc(widget.randomNumber)
          .get();

      setState(() {
        _titleController.text = petDoc['title'];
        _selectedKinds = petDoc['Kinds'];
        _ageController.text = petDoc['age'];
        _genderController = petDoc['gender'];
        _vaccineController = petDoc['vaccine'];
        _adoptionController = petDoc['adoption'];
        _chipController = petDoc['chip'];
        _typeController.text = petDoc['type'];
        _noteController.text = petDoc['note'];
        _phoneNumberController.text = petDoc['phone'];
        _selectedLocation = petDoc['location'];
        _imageUrl = petDoc['imagePath'];
        _serialNumber = petDoc['serialNumber'];
        _placemark = petDoc['placemark'];
      });
    } catch (e) {
      debugPrint('Hayvan verilerini getirirken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hayvan Bilgilerini Güncelle'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            children: [
              Text(
                'Seri Numarası: $_serialNumber',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),
              _buildImagePicker(), // Image picker button added

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
                onPressed: _isUpdating ? null : _updatePetData,
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

  Widget _buildTitleFieldPhone(
      String labelText, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        LengthLimitingTextInputFormatter(11),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
    );
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
      onPressed: _isUpdating || _isLoadingMap ? null : _selectLocation,
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

  Widget _buildImagePicker() {
    return Column(
      children: [
        if (_imageBytes != null)
          Image.memory(_imageBytes!, height: 150)
        else if (_imageUrl != null)
          AppNetworkImage(
            url: _imageUrl ?? '',
            height: 150,
          ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _pickImage, // Corrected method name
          child: const Text('Resim Seç'),
        ),
      ],
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

    final position = await GeolocatorPlatform.instance.getCurrentPosition();
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

  Future<void> _updatePetData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('User is not authenticated.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    if (_titleController.text.isEmpty ||
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
        _isUpdating = false;
      });
      return;
    }

    // Telefon numarasını doğrulama
    final phoneNumber = _phoneNumberController.text;
    if (phoneNumber.length != 11 ||
        !phoneNumber.contains(RegExp(r'^\d{11}$'))) {
      debugPrint('Geçerli bir 11 haneli telefon numarası girmelisiniz.');
      setState(() {
        _isUpdating = false;
      });
      return;
    }

    try {
      // Upload the image file to Firebase Storage and get the image URL
      if (_imageBytes != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
        final storageRef = FirebaseStorage.instance.ref().child('pets_images').child(fileName);
        await storageRef.putData(_imageBytes!, SettableMetadata(contentType: 'image/png'));
        _imageUrl = await storageRef.getDownloadURL();
      } else if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
        final storageRef = FirebaseStorage.instance.ref().child('pets_images').child(fileName);
        final uploadTask = storageRef.putFile(_imageFile!);
        final snapshot = await uploadTask.whenComplete(() => null);
        _imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Firestore'a yeni hayvan bilgilerini ekleme
      final timestamp = DateTime.now();
      final addedBy = user.email ?? '';

      String? fullName;
      //if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      fullName = userDoc['fullName'];
      //}

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
        if (_imageUrl != null) 'imagePath': _imageUrl,
        'title': _titleController.text,
        'Kinds': _selectedKinds,
        'age': _ageController.text,
        'gender': _genderController,
        'vaccine': _vaccineController,
        'adoption': _adoptionController,
        'chip': _chipController,
        'type': _typeController.text,
        'note': _noteController.text,
        'email': user.email ?? '',
        'phone': phoneNumber,
        'timestamp': timestamp.toUtc(),
        'addedBy': addedBy,
        'userUID': user.uid,
        'fullName': fullName ?? '',
        'ipAddress': ipAddress ?? '',
        'location': _selectedLocation ?? '',
        'serialNumber': _serialNumber ?? '',
        'placemark': _placemark ?? '',

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
      // Update the existing pet document by its original ID.
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(widget.randomNumber)
          .set(petData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Hayvan bilgileri güncellenirken hata oluştu: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hayvan bilgileri güncellenemedi.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}
