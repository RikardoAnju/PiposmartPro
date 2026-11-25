class PaymentMethod {
  final String id;
  final String outletId;
  final String name;
  final String description;
  final String category;
  final int status;
  final String? accountHolder;
  final String? accountNumber;
  final String? bankName;
  final String? ewalletProvider;
  final String? phoneNumber;
  final String? createdAt;
  final String? updatedAt;
  final String? userUpdate;
  final String? userUpdateType;

  PaymentMethod({
    required this.id,
    required this.outletId,
    required this.name,
    required this.description,
    required this.category,
    required this.status,
    this.accountHolder,
    this.accountNumber,
    this.bankName,
    this.ewalletProvider,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
    this.userUpdate,
    this.userUpdateType,
  });

  bool get isActive => status == 1;
  bool get isNobu =>
      category.toLowerCase() == 'qris' && name.toLowerCase().contains('nobu');

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['Status'] ?? json['status'] ?? 0;
    final parsedStatus = rawStatus is int
        ? rawStatus
        : int.tryParse(rawStatus.toString()) ?? 0;

    return PaymentMethod(
      id: json['ID'] ?? json['id'] ?? '',
      outletId: json['OutletID'] ?? json['outlet_id'] ?? '',
      name: json['Nama'] ?? json['name'] ?? '',
      description: json['Deskripsi'] ?? json['description'] ?? '',
      category: (json['Kategori'] ?? json['category'] ?? '').toString(),
      status: parsedStatus,
      accountHolder: json['NamaPemilik'] ?? json['account_holder'],
      accountNumber: json['NomorAkun'] ?? json['account_number'],
      bankName: json['NamaBank'] ?? json['bank_name'],
      ewalletProvider: json['EwalletProvider'] ?? json['ewallet_provider'],
      phoneNumber: json['NomorHP'] ?? json['phone_number'],
      createdAt: json['CreatedAt'] ?? json['created_at'],
      updatedAt: json['UpdatedAt'] ?? json['updated_at'],
      userUpdate: json['UserUpdate'] ?? json['user_update'],
      userUpdateType: json['UserUpdateType'] ?? json['user_update_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'name': name,
      'description': description,
      'category': category,
      'status': status,
      'account_holder': accountHolder,
      'account_number': accountNumber,
      'bank_name': bankName,
      'ewallet_provider': ewalletProvider,
      'phone_number': phoneNumber,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_update': userUpdate,
      'user_update_type': userUpdateType,
    };
  }
}

class PaymentMethodInput {
  final String? outletId;
  final String? category;
  final int? status;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String? ewalletProvider;
  final String? phoneNumber;
  final String? userUpdate;
  final String? userUpdateType;

  PaymentMethodInput({
    this.outletId,
    this.category,
    this.status,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.ewalletProvider,
    this.phoneNumber,
    this.userUpdate,
    this.userUpdateType,
  });

  String? validate() {
    if (category == null || category!.isEmpty) {
      return 'Kategori harus diisi';
    }

    if (category == 'Transfer') {
      if (bankName == null || bankName!.isEmpty) {
        return 'Nama bank harus diisi';
      }
      if (accountNumber == null || accountNumber!.isEmpty) {
        return 'Nomor rekening harus diisi';
      }
      if (accountHolder == null || accountHolder!.isEmpty) {
        return 'Nama pemilik rekening harus diisi';
      }
    }

    if (category == 'E-Wallet') {
      if (ewalletProvider == null || ewalletProvider!.isEmpty) {
        return 'Provider e-wallet harus diisi';
      }
      if (phoneNumber == null || phoneNumber!.isEmpty) {
        return 'Nomor telepon harus diisi';
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (outletId != null) data['outlet_id'] = outletId;
    if (category != null) data['category'] = category;
    if (status != null) data['status'] = status;
    if (bankName != null) data['bank_name'] = bankName;
    if (accountNumber != null) data['account_number'] = accountNumber;
    if (accountHolder != null) data['account_holder'] = accountHolder;
    if (ewalletProvider != null) data['ewallet_provider'] = ewalletProvider;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (userUpdate != null) data['user_update'] = userUpdate;
    if (userUpdateType != null) data['user_update_type'] = userUpdateType;

    return data;
  }
}

class UpdatePaymentMethodInput {
  final String? category;
  final int? status;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String? ewalletProvider;
  final String? phoneNumber;
  final String? userUpdate;
  final String? userUpdateType;

  UpdatePaymentMethodInput({
    this.category,
    this.status,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.ewalletProvider,
    this.phoneNumber,
    this.userUpdate,
    this.userUpdateType,
  });

  String? validate() {
    if (category != null) {
      if (category == 'Transfer') {
        if (bankName != null && bankName!.isEmpty) {
          return 'Nama bank tidak boleh kosong';
        }
        if (accountNumber != null && accountNumber!.isEmpty) {
          return 'Nomor rekening tidak boleh kosong';
        }
        if (accountHolder != null && accountHolder!.isEmpty) {
          return 'Nama pemilik rekening tidak boleh kosong';
        }
      }

      if (category == 'E-Wallet') {
        if (ewalletProvider != null && ewalletProvider!.isEmpty) {
          return 'Provider e-wallet tidak boleh kosong';
        }
        if (phoneNumber != null && phoneNumber!.isEmpty) {
          return 'Nomor telepon tidak boleh kosong';
        }
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (category != null) data['category'] = category;
    if (status != null) data['status'] = status;
    if (bankName != null) data['bank_name'] = bankName;
    if (accountNumber != null) data['account_number'] = accountNumber;
    if (accountHolder != null) data['account_holder'] = accountHolder;
    if (ewalletProvider != null) data['ewallet_provider'] = ewalletProvider;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (userUpdate != null) data['user_update'] = userUpdate;
    if (userUpdateType != null) data['user_update_type'] = userUpdateType;

    return data;
  }
}
