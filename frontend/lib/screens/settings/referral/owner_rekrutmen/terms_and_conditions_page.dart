import 'package:ayocucinew/screens/auth/legal/legal_document_page.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(type: LegalDocumentType.referralTerms);
  }
}
