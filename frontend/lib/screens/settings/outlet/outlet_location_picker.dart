import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_font.dart';

class OutletLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  const OutletLocationPicker({super.key, this.initialLocation});

  @override
  State<OutletLocationPicker> createState() => _OutletLocationPickerState();
}

class _OutletLocationPickerState extends State<OutletLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;

  static const _fallbackLocation = LatLng(-0.9471, 100.4172);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'GPS belum aktif. Aktifkan lokasi perangkat lalu coba lagi.',
          actionLabel: 'Buka GPS',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage(
          'Izin lokasi diperlukan untuk menentukan titik outlet.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Izin lokasi diblokir. Aktifkan dari pengaturan aplikasi.',
          actionLabel: 'Buka Pengaturan',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _selectedLocation = location);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 17),
      );
    } catch (_) {
      _showLocationMessage(
        'Lokasi belum terbaca. Pastikan GPS aktif lalu coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationMessage(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: () => onAction()),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final location = _selectedLocation ?? _fallbackLocation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi Outlet'),
        titleTextStyle: const TextStyle(
          color: Color(0xFF34495E),
          fontSize: 16,
          fontWeight: AppFont.w800,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF34495E)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Gunakan lokasi saya',
            onPressed: _isLoadingLocation ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: location, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              final selected = _selectedLocation;
              if (selected != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(selected, 17),
                );
              }
            },
            onTap: (value) => setState(() => _selectedLocation = value),
            markers: _selectedLocation == null
                ? const <Marker>{}
                : {
                    Marker(
                      markerId: const MarkerId('outlet'),
                      position: _selectedLocation!,
                      infoWindow: const InfoWindow(title: 'Lokasi Outlet'),
                    ),
                  },
            circles: _selectedLocation == null
                ? const <Circle>{}
                : {
                    Circle(
                      circleId: const CircleId('attendance-radius'),
                      center: _selectedLocation!,
                      radius: 5,
                      fillColor: const Color(0x3327AE60),
                      strokeColor: const Color(0xFF27AE60),
                      strokeWidth: 2,
                    ),
                  },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              color: Colors.white,
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _isLoadingLocation ? null : _useCurrentLocation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFFFF6B3D),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gunakan lokasi saya',
                              style: TextStyle(
                                color: Color(0xFF34495E),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isLoadingLocation
                                  ? 'Sedang membaca lokasi...'
                                  : 'Tekan untuk memilih lokasi outlet saat ini',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isLoadingLocation)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFFF6B3D),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Colors.white,
                elevation: 6,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi outlet terpilih',
                        style: TextStyle(
                          color: Color(0xFF34495E),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                          '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Area hijau menunjukkan radius absensi 5 meter',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedLocation == null
                              ? null
                              : () => Navigator.pop(context, _selectedLocation),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFF6B3D),
                            elevation: 0,
                            side: const BorderSide(
                              color: Color(0xFFFF6B3D),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('SAVE AREA'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
