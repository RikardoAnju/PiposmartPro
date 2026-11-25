import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/providers/role_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PermissionDetailModal extends StatelessWidget {
  final Pegawai emp;
  const PermissionDetailModal({super.key, required this.emp});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppPalette.primary; // Orange AyoCuci
    const Color darkColor = Color(0xFF2C3E50);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle Bar
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // --- HEADER PROFIL PADAT ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person_rounded,
                        color: primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.nama.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.w900,
                              color: darkColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emp.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: AppFont.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildRoleBadge(emp.role?.nama ?? "STAFF"),
                              const SizedBox(width: 6),
                              _buildStatusBadge(emp),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Info Tambahan (Padat)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildInfoItem(Icons.phone_android_rounded, emp.nohp),
                      Container(width: 1, height: 20, color: Colors.grey[300]),
                      _buildInfoItem(
                        Icons.calendar_today_rounded,
                        "Join: ${DateFormat('dd/MM/yy').format(emp.createdAt)}",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),

          // --- CONTENT: PERMISSION LIST (STYLE MAINTAINED) ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "HAK AKSES MODUL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.w900,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (emp.role?.permissions == null ||
                      emp.role!.permissions.isEmpty)
                    _buildNoPermissionState()
                  else
                    ...emp.role!.permissions.entries.map((entry) {
                      final module = _moduleLabel(entry.key).toUpperCase();
                      final List actions = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1F3F5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  module,
                                  style: const TextStyle(
                                    fontWeight: AppFont.w800,
                                    fontSize: 13,
                                    color: darkColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: actions.map((a) {
                                bool isAll =
                                    a.toString().toLowerCase() == 'all';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAll
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _actionLabel(a.toString()).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: AppFont.w900,
                                      color: isAll ? Colors.blue : primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),

          // --- ACTION BUTTON (KONSISTEN ORANGE) ---
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "TUTUP DETAIL",
                    style: TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER COMPONENT (CONSISTENT STYLE) ---

  Widget _buildRoleBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6C757D),
          fontSize: 9,
          fontWeight: AppFont.w800,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Pegawai emp) {
    Color color;
    String label;

    switch (emp.statusType) {
      case EmployeeStatusType.base:
        color = AppPalette.primary;
        label = "SISTEM";
        break;
      case EmployeeStatusType.addonActive:
        color = Colors.blue;
        label = "AKTIF";
        break;
      case EmployeeStatusType.addonInactive:
        color = Colors.amber[800]!;
        label = "BELUM AKTIF";
        break;
      case EmployeeStatusType.addonExpired:
        color = Colors.red;
        label = "KADALUARSA";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: AppFont.w900,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: AppFont.w600,
                color: Color(0xFF2C3E50),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPermissionState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          "Tidak ada hak akses yang diatur untuk role ini.",
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  String _moduleLabel(String key) => RoleProvider.moduleLabel(key);

  String _actionLabel(String key) => RoleProvider.actionLabel(key);
}
