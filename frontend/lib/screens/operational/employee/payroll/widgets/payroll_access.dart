part of '../../payroll_screen.dart';

class _PayrollAccessDenied extends StatelessWidget {
  const _PayrollAccessDenied();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppPalette.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Akses Terbatas',
              style: TextStyle(
                color: AppPalette.ink,
                fontSize: 18,
                fontWeight: AppFont.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Menu penggajian hanya dapat diakses oleh pemilik outlet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollWelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onBack;

  const _PayrollWelcomeScreen({required this.onStart, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: onBack,
        ),
        title: const Text(
          'Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 210,
                height: 220,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/maskot/maskot.webp',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Selamat Datang di Penggajian!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 20,
                  fontWeight: AppFont.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Atur gaji setiap karyawan terlebih dahulu agar sistem dapat membuat penggajian secara otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ATUR GAJI SEKARANG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: AppFont.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
