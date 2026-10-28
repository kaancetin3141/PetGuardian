import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../stuff/image_helper.dart';
import './map_screen.dart';

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
  String? _adoptionController; // sahiplendirme
  String? _genderController; // cinsiyet
  String? _selectedLocation; // insan-okur konum etiketi
  String? userUID;
  final firebaseAuth = FirebaseAuth.instance;

  bool _isUploading = false;
  bool _isLoadingMap = false;

  @override
  void dispose() {
    _titleController.dispose();
    _ageController.dispose();
    _typeController.dispose();
    _noteController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evcil Hayvan Ekle'),
        centerTitle: true,
      ),
      body: Center(
        // Wide screens (web/desktop) get a form column instead of a
        // full-bleed 50px-padded strip.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotoPicker(scheme),
                const SizedBox(height: 16),
                _buildDropdown(
                  _selectedKinds,
                  'Cins Seç',
                  (String? newValue) => setState(() => _selectedKinds = newValue),
                  const ['Kedi', 'Köpek', 'Kuş', 'Balık', 'Diğer'],
                ),
                const SizedBox(height: 16),
                _buildTextField('Hayvan İsmi', _titleController),
                const SizedBox(height: 16),
                _buildTextField(
                  'Yaş',
                  _ageController,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  _genderController,
                  'Cinsiyet Seç',
                  (String? newValue) => setState(() => _genderController = newValue),
                  const [
                    'Erkek (Kısır)',
                    'Erkek (Kısır Değil)',
                    'Dişi (Kısır)',
                    'Dişi (Kısır Değil)',
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  _chipController,
                  'Çip Durumu',
                  (String? newValue) => setState(() => _chipController = newValue),
                  const ['Çip Takılı', 'Çip Takılı değil', 'Bilinmiyor'],
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  _vaccineController,
                  'Aşı Durumu',
                  (String? newValue) => setState(() => _vaccineController = newValue),
                  const ['Aşıları Tam', 'Aşıları Eksik', 'Bilinmiyor'],
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  _adoptionController,
                  'Sahiplendirme Durumu',
                  (String? newValue) => setState(() => _adoptionController = newValue),
                  const [
                    'Daha Önce Sahiplendirildi',
                    'Daha Önce Sahiplendirilmedi',
                    'Bilinmiyor',
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Hayvanın Türü (ırk)', _typeController),
                const SizedBox(height: 16),
                _buildTextField(
                  'Telefon Numarası (11 Rakam)',
                  _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Not', _noteController, maxLines: 4),
                const SizedBox(height: 16),
                _buildLocationSection(scheme),
                const SizedBox(height: 24),
                _buildSaveButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker(ColorScheme scheme) {
    Widget preview;
    if (_imageBytes != null) {
      preview = Image.memory(
        _imageBytes!,
        key: const ValueKey<String>('bytes'),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else if (_imageFile != null) {
      preview = Image.file(
        _imageFile!,
        key: const ValueKey<String>('file'),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else {
      preview = Column(
        key: const ValueKey<String>('empty'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Fotoğraf Seç',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 220,
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            // The three preview states are cropped to the same box, so a pure
            // cross-fade reads best.
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: preview,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String labelText,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: formatters,
      // No custom colors: the Material 3 theme styles idle/focus/error states
      // for both light and dark mode.
      decoration: InputDecoration(labelText: labelText),
    );
  }

  Widget _buildDropdown(
    String? value,
    String labelText,
    void Function(String?) onChanged,
    List<String> items,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: _isUploading ? null : onChanged,
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      decoration: InputDecoration(labelText: labelText),
    );
  }

  Future<void> _pickImage() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf seçilemedi.')),
        );
      }
    }
  }

  Future<void> _selectLocation() async {
    // permission_handler has no web implementation; the browser prompts for
    // geolocation itself, so only ask on mobile.
    if (!kIsWeb) {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isDenied) {
          debugPrint('Location permission is required to access the map.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Konum izni olmadan harita açılamaz.'),
              ),
            );
          }
          return;
        }
      }
    }

    setState(() => _isLoadingMap = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final selectedLatLng = await Navigator.push<LatLng?>(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            initialLocation: LatLng(position.latitude, position.longitude),
          ),
        ),
      );
      if (!mounted || selectedLatLng == null) return;

      setState(() {
        _selectedLatLng = selectedLatLng;
        _selectedLocation =
            '${selectedLatLng.latitude.toStringAsFixed(5)}, '
            '${selectedLatLng.longitude.toStringAsFixed(5)}';
      });

      // Give the label a human-readable name when reverse geocoding is
      // available. A failure here (unsupported platform, no network) must
      // not abort the pick, let alone the later upload.
      try {
        final placemark = await Geocoding().placemarkFromCoordinates(
          selectedLatLng.latitude,
          selectedLatLng.longitude,
        );
        if (mounted && placemark.isNotEmpty) {
          final first = placemark.first;
          final parts = [first.locality, first.administrativeArea]
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            setState(() => _selectedLocation = parts.join(', '));
          }
        }
      } catch (e) {
        debugPrint('Reverse geocode failed, keeping coordinates: $e');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum alınamadı. Tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  Widget _buildLocationSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _isUploading ? null : _selectLocation,
          icon: _isLoadingMap
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.location_on_outlined),
          label: Text(
            _selectedLatLng == null ? 'Konum Seç' : 'Konumu Değiştir',
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedLocation == null
              ? const SizedBox(key: ValueKey<String>('no-location'), height: 0)
              : Padding(
                  key: const ValueKey<String>('location'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.place, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedLocation!,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: _isUploading ? null : _uploadPetData,
      icon: _isUploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.publish),
      label: Text(_isUploading ? 'Yükleniyor…' : 'İlanı Yayınla'),
    );
  }

  /// Collects every problem with the form and shows ONE snackbar naming the
  /// missing fields. Previously failures were silent (debugPrint only), so
  /// users saw the save button do nothing.
  bool _validateForm() {
    final problems = <String>[
      if (_imageFile == null && _imageBytes == null) 'Fotoğraf',
      if (_selectedKinds == null) 'Cins',
      if (_titleController.text.trim().isEmpty) 'Hayvan İsmi',
      if (_ageController.text.trim().isEmpty) 'Yaş',
      if (_genderController == null) 'Cinsiyet',
      if (_chipController == null) 'Çip Durumu',
      if (_vaccineController == null) 'Aşı Durumu',
      if (_adoptionController == null) 'Sahiplendirme',
      if (_typeController.text.trim().isEmpty) 'Hayvanın Türü',
      if (_phoneNumberController.text.trim().isEmpty) 'Telefon',
      if (_selectedLocation == null) 'Konum',
    ];
    if (problems.isNotEmpty) {
      _showProblem('Eksik alanlar: ${problems.join(', ')}');
      return false;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 0 || age > 50) {
      _showProblem('Yaş 0-50 arası bir sayı olmalıdır.');
      return false;
    }
    if (!RegExp(r'^\d{11}$').hasMatch(_phoneNumberController.text.trim())) {
      _showProblem('Telefon numarası 11 rakam olmalıdır.');
      return false;
    }
    return true;
  }

  void _showProblem(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _uploadPetData() async {
    if (!_validateForm()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showProblem('Oturumunuz dolmuş. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() => _isUploading = true);

    // Captured so the success callback stays valid after popping this page.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Firebase Storage'a resim yükleme
      final randomNumber = _generateRandomNumber();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('pets_images')
          .child('$randomNumber.jpg');
      if (kIsWeb && _imageBytes != null) {
        await storageRef.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (_imageFile != null) {
        await storageRef.putFile(_imageFile!);
      }

      final imageUrl = await storageRef.getDownloadURL();

      final timestamp = DateTime.now();
      final addedBy = user.email ?? '';

      String? fullName;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      fullName = userDoc.data()?['fullName']?.toString();

      String? ipAddress;
      try {
        final response = await http
            .get(Uri.parse('https://api.ipify.org?format=json'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>?;
          ipAddress = data?['ip']?.toString();
        }
      } catch (e) {
        debugPrint('IP adresi alınırken hata oluştu: $e');
      }

      final petData = {
        'serialNumber': randomNumber,
        'imagePath': imageUrl,
        'title': _titleController.text.trim(),
        'Kinds': _selectedKinds,
        'age': _ageController.text.trim(),
        'gender': _genderController,
        'vaccine': _vaccineController,
        'adoption': _adoptionController,
        'chip': _chipController,
        'type': _typeController.text.trim(),
        'note': _noteController.text.trim(),
        'email': user.email ?? '',
        'phone': _phoneNumberController.text.trim(),
        'timestamp': timestamp.toUtc(),
        'addedBy': addedBy,
        'userUID': user.uid,
        'fullName': fullName ?? '',
        'ipAddress': ipAddress ?? '',
        'location': _selectedLocation ?? '',
      };

      if (_selectedLatLng != null) {
        petData['geopoint'] = GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        );
        // Plain doubles: the feed's distance sort and the per-card distance
        // badge read these. geopoint alone is not enough for them.
        petData['latitude'] = _selectedLatLng!.latitude;
        petData['longitude'] = _selectedLatLng!.longitude;

        try {
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
        } catch (e) {
          debugPrint('Placemark alınamadı, koordinatlarla devam: $e');
        }
      }

      // hayvanı firebaseye kaydet
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(randomNumber)
          .set(petData);

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('İlan yayınlandı 🐾'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Hayvan bilgileri kaydedilirken hata oluştu: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hayvan kaydedilemedi. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _generateRandomNumber() {
    final random = Random.secure();
    final values = List<int>.generate(11, (_) => random.nextInt(10));
    return values.join();
  }
}
