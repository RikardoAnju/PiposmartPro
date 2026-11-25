import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:convert';
import 'package:ayocucinew/core/theme/app_palette.dart';

import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/legal_document_model.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

enum LegalDocumentType { terms, privacy, referralTerms }

class LegalDocumentPage extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentPage({super.key, required this.type});

  String get _typeKey {
    switch (type) {
      case LegalDocumentType.terms:
        return 'terms';
      case LegalDocumentType.privacy:
        return 'privacy';
      case LegalDocumentType.referralTerms:
        return 'referral_terms';
    }
  }

  String get _fallbackTitle {
    switch (type) {
      case LegalDocumentType.terms:
        return 'SYARAT & KETENTUAN';
      case LegalDocumentType.privacy:
        return 'KEBIJAKAN PRIVASI';
      case LegalDocumentType.referralTerms:
        return 'SYARAT REFERRAL';
    }
  }

  Future<LegalDocumentModel> _fetchDocument() async {
    final response = await ApiClient.get('/legal-documents/$_typeKey');
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded['status'] != true) {
      throw Exception(decoded['message'] ?? 'Gagal memuat dokumen legal');
    }

    return LegalDocumentModel.fromJson(decoded['data'] ?? {});
  }

  List<_LegalSection> _parseSections(String body) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];

    final lines = normalized.split('\n');
    final sections = <_LegalSection>[];
    String? currentTitle;
    final buffer = <String>[];

    void flush() {
      final content = buffer.join('\n').trim();
      if (content.isEmpty && currentTitle == null) return;
      sections.add(
        _LegalSection(title: currentTitle ?? 'Informasi', content: content),
      );
      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.startsWith('## ')) {
        flush();
        currentTitle = line.substring(3).trim();
        continue;
      }
      buffer.add(line);
    }
    flush();

    if (sections.isEmpty) {
      return [_LegalSection(title: 'Informasi', content: normalized)];
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.primary,
              AppPalette.primaryWarm,
              AppPalette.primaryBorder,
              AppPalette.primaryPale,
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<LegalDocumentModel>(
            future: _fetchDocument(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 220,
                    child: AppCircularLoader(color: Colors.white),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _LegalErrorState(
                  title: _fallbackTitle,
                  onRetry: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => LegalDocumentPage(type: type),
                      ),
                    );
                  },
                );
              }

              final doc = snapshot.data!;
              final sections = _parseSections(doc.body);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Text(
                          'Kembali',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: AppFont.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      doc.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: AppFont.w700,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      doc.effectiveLabel.isNotEmpty
                          ? doc.effectiveLabel
                          : 'Terakhir diperbarui',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: AppFont.w400,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final section in sections)
                              _LegalSectionView(section: section),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String content;

  const _LegalSection({required this.title, required this.content});
}

class _LegalSectionView extends StatelessWidget {
  final _LegalSection section;

  const _LegalSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: AppFont.w700,
                    color: Color(0xFF333333),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            section.content,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: AppFont.w400,
              color: Color(0xFF666666),
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalErrorState extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const _LegalErrorState({required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Text(
                  'Kembali',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: AppFont.w400,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dokumen belum berhasil dimuat. Silakan coba lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppPalette.primary,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
