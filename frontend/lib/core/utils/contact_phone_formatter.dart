import 'package:flutter_contacts/flutter_contacts.dart';

String pickContactPhoneNumber(Iterable<Phone> phones) {
  final phoneList = phones.toList();
  final orderedPhones = [
    ...phoneList.where((phoneEntry) => phoneEntry.isPrimary == true),
    ...phoneList.where((phoneEntry) => phoneEntry.isPrimary != true),
  ];

  for (final phoneEntry in orderedPhones) {
    final normalizedPhone = normalizeContactPhone(phoneEntry.normalizedNumber);
    if (normalizedPhone.isNotEmpty) return normalizedPhone;

    final fallbackPhone = normalizeContactPhone(phoneEntry.number);
    if (fallbackPhone.isNotEmpty) return fallbackPhone;
  }

  return '';
}

String normalizeContactPhone(String? rawPhone) {
  final digitsOnly = (rawPhone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) return '';

  if (digitsOnly.startsWith('62')) {
    return '0${digitsOnly.substring(2)}';
  }

  if (digitsOnly.startsWith('8')) {
    return '0$digitsOnly';
  }

  return digitsOnly;
}
