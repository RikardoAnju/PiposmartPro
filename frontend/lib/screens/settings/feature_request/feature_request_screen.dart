import 'dart:convert';
import 'dart:io';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:ayocucinew/core/utils/image_picker_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class FeatureRequestScreen extends StatefulWidget {
  const FeatureRequestScreen({super.key});

  @override
  State<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends State<FeatureRequestScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
  String _sort = 'popular';

  static const _statusLabels = <String, String>{
    'ALL': 'Semua',
    'SUBMITTED': 'Diajukan',
    'UNDER_REVIEW': 'Dipertimbangkan',
    'IN_PROGRESS': 'Dikerjakan',
    'COMPLETED': 'Selesai',
    'NOT_PLANNED': 'Belum Bisa',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.get(
        '/feature-requests?status=$_status&sort=$_sort',
        token: AuthStorage.token,
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['status'] != true) {
        throw Exception(body['message'] ?? 'Usulan belum bisa dimuat');
      }
      if (!mounted) return;
      setState(() {
        _items = (body['data'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Usulan fitur belum bisa dimuat. Coba lagi ya.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleVote(Map<String, dynamic> item) async {
    final oldVoted = item['has_voted'] == true;
    final oldCount = (item['vote_count'] as num?)?.toInt() ?? 0;
    setState(() {
      item['has_voted'] = !oldVoted;
      item['vote_count'] = oldCount + (oldVoted ? -1 : 1);
    });
    try {
      final response = await ApiClient.post(
        '/feature-requests/${item['id']}/vote',
        token: AuthStorage.token,
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['status'] != true) {
        throw Exception();
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      if (!mounted) return;
      setState(() {
        item['has_voted'] = data['has_voted'] == true;
        item['vote_count'] = (data['vote_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item['has_voted'] = oldVoted;
        item['vote_count'] = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote belum tersimpan. Coba lagi ya.')),
      );
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateFeatureRequestSheet(),
    );
    if (created == true) {
      _status = 'ALL';
      _sort = 'newest';
      await _load();
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeatureDetailSheet(item: item),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Request Fitur',
          style: TextStyle(fontSize: 17, fontWeight: AppFont.w700),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _openCreateSheet,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Usulkan Fitur',
                style: TextStyle(fontWeight: AppFont.w700),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppPalette.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bantu tentukan fitur berikutnya',
                      style: TextStyle(fontSize: 20, fontWeight: AppFont.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Lihat ide pengguna lain, beri vote, atau kirim kebutuhan usahamu.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusLabels.entries.map((entry) {
                          final selected = _status == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _status = entry.key);
                                _load();
                              },
                              selectedColor: AppPalette.primary,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.blueGrey.shade700,
                                fontSize: 12,
                                fontWeight: AppFont.w600,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? AppPalette.primary
                                    : Colors.grey.shade200,
                              ),
                              backgroundColor: Colors.white,
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Urutkan:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        _SortButton(
                          label: 'Terpopuler',
                          selected: _sort == 'popular',
                          onTap: () {
                            setState(() => _sort = 'popular');
                            _load();
                          },
                        ),
                        _SortButton(
                          label: 'Terbaru',
                          selected: _sort == 'newest',
                          onTap: () {
                            setState(() => _sort = 'newest');
                            _load();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppPalette.primary),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: _error!,
                  action: _load,
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Belum ada usulan pada status ini.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _FeatureCard(
                    item: _items[index],
                    onVote: () => _toggleVote(_items[index]),
                    onOpen: () => _openDetail(_items[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.item,
    required this.onVote,
    required this.onOpen,
  });
  final Map<String, dynamic> item;
  final VoidCallback onVote;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'SUBMITTED';
    final voted = item['has_voted'] == true;
    final colors = _statusColors(status);
    DateTime? createdAt = DateTime.tryParse(
      item['created_at']?.toString() ?? '',
    );
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onVote,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: voted
                      ? const Color(0xFFFFF0EA)
                      : const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: voted ? AppPalette.primary : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      voted
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_upward_outlined,
                      size: 19,
                      color: voted ? AppPalette.primary : Colors.blueGrey,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['vote_count'] ?? 0}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: voted
                            ? AppPalette.primary
                            : Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _FeatureRequestScreenState._statusLabels[status] ??
                          status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w700,
                        color: colors.$2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item['title']?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF263849),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['description']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  if ((item['admin_note']?.toString().trim() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.$1.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Update tim: ${item['admin_note']}',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: colors.$2,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${item['creator_name'] ?? 'Pengguna AyoCuci'}${createdAt == null ? '' : ' • ${DateFormat('d MMM yyyy', 'id_ID').format(createdAt.toLocal())}'}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _statusColors(String status) => switch (status) {
    'UNDER_REVIEW' => (const Color(0xFFFFF4D6), const Color(0xFF9A6B00)),
    'IN_PROGRESS' => (const Color(0xFFE7F0FF), const Color(0xFF2563A7)),
    'COMPLETED' => (const Color(0xFFE4F7EC), const Color(0xFF16804A)),
    'NOT_PLANNED' => (const Color(0xFFF1F2F4), const Color(0xFF68717C)),
    _ => (const Color(0xFFFFE9E1), AppPalette.primary),
  };
}

class _FeatureDetailSheet extends StatefulWidget {
  const _FeatureDetailSheet({required this.item});
  final Map<String, dynamic> item;
  @override
  State<_FeatureDetailSheet> createState() => _FeatureDetailSheetState();
}

class _FeatureDetailSheetState extends State<_FeatureDetailSheet> {
  late Map<String, dynamic> item = Map<String, dynamic>.from(widget.item);
  bool changed = false;

  Future<void> _edit() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateFeatureRequestSheet(initial: item),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteAttachment(Map<String, dynamic> attachment) async {
    final response = await ApiClient.delete(
      '/feature-requests/${item['id']}/attachments/${attachment['id']}',
      token: AuthStorage.token,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['status'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Lampiran belum bisa dihapus'),
          ),
        );
      }
      return;
    }
    setState(() {
      final attachments = List<Map<String, dynamic>>.from(
        (item['attachments'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      attachments.removeWhere((e) => e['id'] == attachment['id']);
      item['attachments'] = attachments;
      changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attachments = (item['attachments'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final canEdit = item['is_mine'] == true && item['status'] == 'SUBMITTED';
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Detail Usulan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      onPressed: _edit,
                      tooltip: 'Edit usulan',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppPalette.primary,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, changed),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item['creator_name'] ?? 'Pengguna AyoCuci'} • ${item['vote_count'] ?? 0} vote',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      item['description']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Lampiran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: attachments.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final attachment = attachments[index];
                            final url = ApiClient.resolveUploadUrl(
                              attachment['file_url']?.toString(),
                            );
                            return Stack(
                              children: [
                                InkWell(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.black,
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      url,
                                      width: 112,
                                      height: 112,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (canEdit)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: InkWell(
                                      onTap: () =>
                                          _deleteAttachment(attachment),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    if ((item['admin_note']?.toString().trim() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update dari tim AyoCuci',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item['admin_note'].toString(),
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Usulan dapat diedit selama statusnya masih Diajukan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFeatureRequestSheet extends StatefulWidget {
  const _CreateFeatureRequestSheet({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_CreateFeatureRequestSheet> createState() =>
      _CreateFeatureRequestSheetState();
}

class _CreateFeatureRequestSheetState
    extends State<_CreateFeatureRequestSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<File> _attachments = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.text = widget.initial?['title']?.toString() ?? '';
    _description.text = widget.initial?['description']?.toString() ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 5 || _description.text.trim().length < 10) {
      setState(
        () => _error = 'Isi judul dan ceritakan kebutuhannya lebih lengkap ya.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.initial?['id']?.toString();
      final payload = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
      };
      final response = id == null
          ? await ApiClient.post(
              '/feature-requests',
              token: AuthStorage.token,
              body: payload,
            )
          : await ApiClient.put(
              '/feature-requests/$id',
              token: AuthStorage.token,
              body: payload,
            );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if ((response.statusCode != 201 && response.statusCode != 200) ||
          body['status'] != true) {
        throw Exception(body['message']);
      }
      final requestID = id ?? (body['data'] as Map)['id'].toString();
      for (final file in _attachments) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(
            '${ApiClient.baseUrl}/feature-requests/$requestID/attachments',
          ),
        );
        request.headers['Authorization'] = 'Bearer ${AuthStorage.token}';
        request.files.add(
          await http.MultipartFile.fromPath('attachment', file.path),
        );
        final upload = await http.Response.fromStream(await request.send());
        if (upload.statusCode != 201) {
          final uploadBody = jsonDecode(upload.body) as Map<String, dynamic>;
          throw Exception(uploadBody['message'] ?? 'Gagal mengunggah lampiran');
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickAttachment() async {
    final existing = (widget.initial?['attachments'] as List?)?.length ?? 0;
    if (existing + _attachments.length >= 3) {
      setState(() => _error = 'Maksimal 3 gambar per usulan.');
      return;
    }
    final file = await ImagePickerHelper.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() {
        _attachments.add(file);
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.initial == null
                  ? 'Usulkan fitur baru'
                  : 'Edit usulan fitur',
              style: TextStyle(fontSize: 20, fontWeight: AppFont.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'Ceritakan masalah yang ingin diselesaikan, bukan hanya nama fiturnya.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Judul usulan',
                hintText: 'Contoh: Pengingat cucian via WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Tambah Gambar'),
                ),
                const SizedBox(width: 10),
                Text(
                  '${((widget.initial?['attachments'] as List?)?.length ?? 0) + _attachments.length}/3',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _attachments[index],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _attachments.removeAt(index)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLength: 1500,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kebutuhan dan manfaat',
                hintText:
                    'Jelaskan kapan fitur ini dibutuhkan dan bagaimana membantu usaha Anda.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.initial == null
                            ? 'Kirim Usulan'
                            : 'Simpan Perubahan',
                        style: TextStyle(fontWeight: AppFont.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      foregroundColor: selected ? AppPalette.primary : Colors.grey,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: selected ? AppFont.w700 : AppFont.w500,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}
