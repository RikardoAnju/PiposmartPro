part of '../../employee_attendance_screen.dart';

Widget _header(String name) => Padding(
  padding: EdgeInsets.zero,
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF7043), Color(0xFFFFA646)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $name',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pantau kehadiran dan lakukan absensi Anda hari ini.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  ),
);

class _LiveClockCard extends StatefulWidget {
  const _LiveClockCard();

  @override
  State<_LiveClockCard> createState() => _LiveClockCardState();
}

class _LiveClockCardState extends State<_LiveClockCard> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kehadiran Hari Ini',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: Color(0xFF526273),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              DateFormat('hh : mm : ss a').format(_now),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: AppFont.w900,
                letterSpacing: 1.2,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_now),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7B8794),
                fontWeight: AppFont.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _locationCard(
  dynamic outlet,
  bool outletLocationConfigured,
  LatLng outletPoint,
  LatLng employeePoint,
  double? distance,
  bool isInside,
  bool loadingLocation,
  String? locationError,
  ValueChanged<GoogleMapController> onMapCreated,
  VoidCallback onRefreshLocation,
) => Container(
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  ),
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppPalette.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Lokasi saat ini',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34495E),
                ),
              ),
            ),
            if (loadingLocation)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _statusPill(
                !outletLocationConfigured
                    ? 'Belum diatur'
                    : (isInside ? 'Di dalam area' : 'Di luar area'),
                outletLocationConfigured && isInside,
              ),
          ],
        ),
      ),
      SizedBox(
        height: 190,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: employeePoint,
                zoom: 15,
              ),
              onMapCreated: onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: outletLocationConfigured
                  ? {
                      Marker(
                        markerId: const MarkerId('outlet'),
                        position: outletPoint,
                        infoWindow: InfoWindow(title: outlet?.nama ?? 'Outlet'),
                      ),
                    }
                  : const <Marker>{},
              circles: outletLocationConfigured
                  ? {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: outletPoint,
                        // Samakan lingkaran peta dengan toleransi geofence backend.
                        radius: ((outlet?.locationRadiusMeters ?? 5) + 10).toDouble(),
                        fillColor: const Color(0x3327AE60),
                        strokeColor: const Color(0xFF27AE60),
                        strokeWidth: 2,
                      ),
                    }
                  : const <Circle>{},
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  tooltip: 'Sesuaikan lokasi',
                  onPressed: loadingLocation ? null : onRefreshLocation,
                  icon: loadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  color: AppPalette.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.near_me_rounded,
              size: 17,
              color: Color(0xFF718096),
            ),
            const SizedBox(width: 7),
            Text(
              !outletLocationConfigured
                  ? 'Lokasi outlet belum diatur owner'
                  : (distance == null
                        ? 'Lokasi belum terbaca'
                        : '${distance.toStringAsFixed(0)} meter dari outlet'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
          ],
        ),
      ),
      if (!loadingLocation && !outletLocationConfigured)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.gps_off_rounded, size: 17, color: Color(0xFFE68A00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Owner belum mengatur titik lokasi outlet. Hubungi owner untuk menyimpan lokasi outlet.',
                  style: TextStyle(
                    color: Color(0xFF9A6200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

Widget _outletLocationNotConfiguredCard() => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFE68A00),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Lokasi absensi belum tersedia',
            style: TextStyle(
              color: Color(0xFF34495E),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Owner belum menentukan koordinat outlet. Silakan hubungi owner agar lokasi outlet disimpan terlebih dahulu.',
        style: TextStyle(
          color: Color(0xFF718096),
          fontSize: 12,
          height: 1.45,
        ),
      ),
    ],
  ),
);

Widget _statusPill(String text, bool active) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
  decoration: BoxDecoration(
    color: active ? const Color(0xFFE5F8EF) : const Color(0xFFFFECE8),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: active ? const Color(0xFF16B979) : const Color(0xFFE45757),
    ),
  ),
);

Widget _actionButton(
  String label,
  IconData icon,
  bool enabled,
  VoidCallback onTap, {
  bool outlined = false,
}) => SizedBox(
  height: 50,
  child: ElevatedButton.icon(
    onPressed: enabled ? onTap : null,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: outlined ? Colors.white : AppPalette.primary,
      foregroundColor: outlined ? AppPalette.primary : Colors.white,
      elevation: 0,
      side: outlined ? const BorderSide(color: AppPalette.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
);

Widget _sectionTitle(String text) => Text(
  text,
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    color: Color(0xFF34495E),
    fontSize: 15,
  ),
);

Widget _summary(String label, String value, Color color) => Expanded(
  child: Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  ),
);

Widget _noteChip(String text, Color color) => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline_rounded, size: 14, color: color),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ],
  ),
);
