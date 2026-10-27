import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapScreen extends StatefulWidget {
  final LatLng initialLocation;
  final MapController mapController = MapController();

  MapScreen({super.key, required this.initialLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _selectedLatLng;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 95),
            Icon(
              Icons.pets,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 12),
            Text(
              'PetGuardian',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 12),
            Icon(
              Icons.pets,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              widget.mapController.move(
                widget.mapController.camera.center,
                widget.mapController.camera.zoom + 1,
              );
            },
            icon: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IconButton(
            onPressed: () {
              widget.mapController.move(
                widget.mapController.camera.center,
                widget.mapController.camera.zoom - 1,
              );
            },
            icon: Icon(
              Icons.remove,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Geri Dön butonunu iptal eder
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(20)),
                hintText: 'Adres Ara',
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIcon: IconButton(
                  icon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _adresAra,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              initialCenter: widget.initialLocation,
              initialZoom: 13.0,
              onTap: (TapPosition? tapPosition, LatLng latLng) {
                setState(() {
                  _selectedLatLng = latLng;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(
                          _selectedLatLng!.latitude + 0.00010,
                          _selectedLatLng!
                              .longitude), // Y koordinatına 0.0005 ekleyerek düşürme sağlanır
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap katkıda bulunanlar',
                    onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),
          buildBottomButtons(),
        ],
      ),
    );
  }

  Widget buildBottomButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              onPressed: () {
                Navigator.pop(context);
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.arrow_back),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.pop(context, _selectedLatLng);
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.check),
            ),
            FloatingActionButton(
              onPressed: () async {
                try {
                  Position position = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  );
                  LatLng currentLocation =
                      LatLng(position.latitude, position.longitude);
                  widget.mapController.move(currentLocation, 13.0);

                  setState(() {
                    _selectedLatLng = currentLocation;
                  });
                } catch (e) {
                  debugPrint('Mevcut konum alınırken hata oluştu: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Konum alınamadı. Lütfen konum iznini kontrol edin.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.location_on),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adresAra() async {
    String sorgu = _searchController.text;
    if (sorgu.isNotEmpty) {
      try {
        List<Location> lokasyonlar =
            await Geocoding().locationFromAddress(sorgu);
        if (lokasyonlar.isNotEmpty) {
          LatLng latLng =
              LatLng(lokasyonlar.first.latitude, lokasyonlar.first.longitude);
          widget.mapController.move(latLng, 13.0);

          setState(() {
            _selectedLatLng = latLng;
          });
        }
      } catch (e) {
        debugPrint('Adres arama sırasında hata oluştu: $e');
      }
    }
  }
}
