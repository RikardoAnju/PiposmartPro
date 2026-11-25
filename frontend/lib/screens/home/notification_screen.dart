import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../data/models/notif_model.dart';
import '../../core/utils/api_client.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/app_cached_network_image.dart';
import 'notification_detail_screen.dart'; // Import screen detail baru
import '../../core/service/notification_navigation_service.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _activeTab = 0;
  String _searchQuery = "";
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};
  final Set<int> _openingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Map<String, dynamic> _getCategoryStyle(String category) {
    switch (category.toUpperCase()) {
      case 'PROMO':
        return {
          'asset': 'assets/icons/notification/Promo.webp',
          'icon': Icons.local_offer_rounded,
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'INFO':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'icon': Icons.notifications_none_rounded,
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'SYSTEM':
      case 'ANNOUNCEMENT':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'icon': Icons.campaign_rounded,
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'REFERRAL':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'icon': Icons.group_add_rounded,
          'color': const Color(0xFF16A34A),
          'bg': const Color(0xFFEAFBF0),
        };
      default:
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'icon': Icons.notifications_none_rounded,
          'color': Colors.grey,
          'bg': const Color(0xFFF1F3F5),
        };
    }
  }

  String _getDateGroupName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "Hari Ini";
    if (checkDate == yesterday) return "Kemarin";
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeaderTools(),
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, prov, _) {
                if (prov.isLoading && prov.notifications.isEmpty) {
                  return const ManagementListSkeleton(
                    showSearch: false,
                    itemCount: 5,
                  );
                }

                List<NotifModel> filteredList = prov.notifications.where((n) {
                  bool matchesTab = _activeTab == 0 || n.status == 0;
                  bool matchesSearch =
                      n.judul.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      n.pesan.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                  return matchesTab && matchesSearch;
                }).toList();

                if (filteredList.isEmpty) {
                  return const EmptyStateWidget(
                    title: "Tidak ada notifikasi",
                    message: "Pesan anda akan muncul di sini.",
                  );
                }

                Map<String, List<NotifModel>> grouped = {};
                for (var item in filteredList) {
                  String groupName = _getDateGroupName(item.createdAt);
                  if (grouped[groupName] == null) grouped[groupName] = [];
                  grouped[groupName]!.add(item);
                }

                return _buildGroupedList(grouped);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionActionBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Notifikasi",
        style: TextStyle(fontWeight: AppFont.w800, fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: _toggleSelectAllVisible,
          child: Text(
            _isSelectionMode && _allVisibleSelected() ? "Batal" : "Pilih semua",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: AppFont.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderTools() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          AppSearchField(
            onChanged: (v) => setState(() => _searchQuery = v),
            hintText: "Cari pesan atau info...",
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTabItem(0, "Semua"),
              const SizedBox(width: 8),
              _buildTabItem(1, "Belum Dibaca"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppPalette.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppPalette.primaryDeep : const Color(0xFFDEE2E6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: AppFont.w700,
            fontSize: 12,
            color: isActive ? AppPalette.primaryDeep : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(Map<String, List<NotifModel>> grouped) {
    final bottomPadding = _isSelectionMode ? 92.0 : 16.0;
    return RefreshIndicator(
      onRefresh: () =>
          context.read<NotificationProvider>().fetchNotifications(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          String dateKey = grouped.keys.elementAt(index);
          List<NotifModel> items = grouped[dateKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Text(
                  dateKey,
                  style: const TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
              ),
              ...items.map((n) => _buildNotifCard(n)),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotifCard(NotifModel notif) {
    final style = _getCategoryStyle(notif.kategori);
    final imageUrl = _resolveImageUrl(notif.imageUrl);
    final isSelected = _selectedIds.contains(notif.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSelectionMode)
          Padding(
            padding: const EdgeInsets.only(top: 18, right: 8),
            child: _buildSelectionCircle(isSelected),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppDecorations.card(radius: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onLongPress: () => _enterSelection(notif.id),
                onTap: () async {
                  if (_isSelectionMode) {
                    _toggleSelected(notif.id);
                    return;
                  }
                  if (_openingIds.contains(notif.id)) return;
                  _openingIds.add(notif.id);
                  try {
                    await context.read<NotificationProvider>().markAsRead(
                      notif.id,
                    );
                    if (!mounted) return;
                    // Detail entitas yang valid langsung terbuka. Informasi
                    // umum dan tujuan yang gagal di-resolve tetap bisa dibaca.
                    if (NotificationNavigationService.canOpenDirectly(
                      notif.payload,
                    )) {
                      final opened = await NotificationNavigationService.open(
                        notif.payload,
                      );
                      if (opened || !mounted) return;
                    }
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NotificationDetailScreen(notif: notif),
                      ),
                    );
                  } finally {
                    _openingIds.remove(notif.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: style['bg'],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: AppAssetImage(
                                style['asset'] as String,
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                errorWidget: Icon(
                                  style['icon'],
                                  color: style['color'],
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.judul,
                                  style: TextStyle(
                                    fontWeight: notif.status == 0
                                        ? AppFont.w900
                                        : AppFont.w700,
                                    fontSize: 14,
                                    color: AppPalette.primaryDeep,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif.pesan,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(notif.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: AppFont.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM').format(notif.createdAt),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: AppFont.w700,
                                  color: Colors.grey[400],
                                ),
                              ),
                              if (notif.status == 0 && !_isSelectionMode)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  height: 7,
                                  width: 7,
                                  decoration: const BoxDecoration(
                                    color: AppPalette.primaryDeep,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (imageUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: AppCachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCircle(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 18,
      width: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppPalette.primaryDeep : Colors.white,
        border: Border.all(
          color: selected ? AppPalette.primaryDeep : const Color(0xFFCED4DA),
          width: 1.3,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }

  Widget _buildSelectionActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: Icons.visibility_rounded,
              label: "Tandai dibaca",
              onTap: _selectedIds.isEmpty ? null : _markSelectedRead,
            ),
            _buildActionItem(
              icon: Icons.delete_outline_rounded,
              label: "Hapus notifikasi",
              onTap: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled ? Colors.black : Colors.grey[300],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFont.w700,
                color: enabled ? Colors.black : Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NotifModel> _visibleNotifications() {
    final notifications = context.read<NotificationProvider>().notifications;
    return notifications.where((n) {
      final matchesTab = _activeTab == 0 || n.status == 0;
      final matchesSearch =
          n.judul.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          n.pesan.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();
  }

  void _enterSelection(int id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds = {id};
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _toggleSelectAllVisible() {
    final visibleIds = _visibleNotifications().map((n) => n.id).toSet();
    if (visibleIds.isEmpty) return;
    setState(() {
      if (_isSelectionMode && _selectedIds.containsAll(visibleIds)) {
        _isSelectionMode = false;
        _selectedIds.clear();
      } else {
        _isSelectionMode = true;
        _selectedIds = visibleIds;
      }
    });
  }

  bool _allVisibleSelected() {
    final visibleIds = _visibleNotifications().map((n) => n.id).toSet();
    return visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds);
  }

  Future<void> _markSelectedRead() async {
    final ids = Set<int>.from(_selectedIds);
    await context.read<NotificationProvider>().markSelectedRead(ids);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    final ids = Set<int>.from(_selectedIds);
    await context.read<NotificationProvider>().deleteSelected(ids);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  String? _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return ApiClient.resolveImageVariantUrl(path, width: 960);
  }
}
