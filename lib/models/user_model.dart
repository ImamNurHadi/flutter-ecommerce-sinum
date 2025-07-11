enum UserRole {
  user('user'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'User';
    }
  }
}

class ContactInfo {
  final String label;
  final String phoneNumber;
  final bool isDefault;

  const ContactInfo({
    required this.label,
    required this.phoneNumber,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
    };
  }

  factory ContactInfo.fromMap(Map<String, dynamic> map) {
    return ContactInfo(
      label: map['label'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }

  ContactInfo copyWith({
    String? label,
    String? phoneNumber,
    bool? isDefault,
  }) {
    return ContactInfo(
      label: label ?? this.label,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class AddressInfo {
  final String label;
  final String address;
  final bool isDefault;

  const AddressInfo({
    required this.label,
    required this.address,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'address': address,
      'isDefault': isDefault,
    };
  }

  factory AddressInfo.fromMap(Map<String, dynamic> map) {
    return AddressInfo(
      label: map['label'] ?? '',
      address: map['address'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }

  AddressInfo copyWith({
    String? label,
    String? address,
    bool? isDefault,
  }) {
    return AddressInfo(
      label: label ?? this.label,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? address; // Keep for backward compatibility
  final String? phoneNumber; // Keep for backward compatibility
  final List<ContactInfo> contacts;
  final List<AddressInfo> addresses;
  final String? profileImageUrl;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.address,
    this.phoneNumber,
    this.contacts = const [],
    this.addresses = const [],
    this.profileImageUrl,
    this.role = UserRole.user,
    this.createdAt,
    this.lastLoginAt,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'address': address,
      'phoneNumber': phoneNumber,
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'addresses': addresses.map((a) => a.toMap()).toList(),
      'profileImageUrl': profileImageUrl,
      'role': role.value,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    // Parse contacts
    List<ContactInfo> contacts = [];
    if (data['contacts'] != null) {
      final contactsData = data['contacts'] as List<dynamic>;
      contacts = contactsData.map((c) => ContactInfo.fromMap(c as Map<String, dynamic>)).toList();
    }

    // Parse addresses
    List<AddressInfo> addresses = [];
    if (data['addresses'] != null) {
      final addressesData = data['addresses'] as List<dynamic>;
      addresses = addressesData.map((a) => AddressInfo.fromMap(a as Map<String, dynamic>)).toList();
    }

    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      address: data['address'],
      phoneNumber: data['phoneNumber'],
      contacts: contacts,
      addresses: addresses,
      profileImageUrl: data['profileImageUrl'],
      role: UserRole.fromString(data['role'] ?? 'user'),
      createdAt: data['createdAt'] != null 
          ? DateTime.tryParse(data['createdAt']) 
          : null,
      lastLoginAt: data['lastLoginAt'] != null 
          ? DateTime.tryParse(data['lastLoginAt']) 
          : null,
    );
  }

  // Create UserModel from Firebase User
  factory UserModel.fromFirebaseUser(
    String uid,
    String email,
    String username, {
    String? address,
    String? phoneNumber,
    String? profileImageUrl,
    UserRole role = UserRole.user,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username,
      address: address,
      phoneNumber: phoneNumber,
      profileImageUrl: profileImageUrl,
      role: role,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? address,
    String? phoneNumber,
    List<ContactInfo>? contacts,
    List<AddressInfo>? addresses,
    String? profileImageUrl,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contacts: contacts ?? this.contacts,
      addresses: addresses ?? this.addresses,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // Helper methods for contacts and addresses
  ContactInfo? get defaultContact {
    try {
      return contacts.firstWhere((c) => c.isDefault);
    } catch (e) {
      return contacts.isNotEmpty ? contacts.first : null;
    }
  }

  AddressInfo? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (e) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  // Get primary phone number (for backward compatibility)
  String? get primaryPhoneNumber {
    return defaultContact?.phoneNumber ?? phoneNumber;
  }

  // Get primary address (for backward compatibility)
  String? get primaryAddress {
    return defaultAddress?.address ?? address;
  }

  // Check if user has complete profile
  bool get isProfileComplete {
    return username.isNotEmpty && email.isNotEmpty;
  }

  // Check if user has contact info for checkout
  bool get hasContactInfo {
    return contacts.isNotEmpty || phoneNumber != null;
  }

  // Check if user has address info for checkout
  bool get hasAddressInfo {
    return addresses.isNotEmpty || address != null;
  }

  // Get display name (username or email)
  String get displayName {
    return username.isNotEmpty ? username : email.split('@')[0];
  }

  // Get initials for avatar
  String get initials {
    if (username.isNotEmpty) {
      List<String> names = username.split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return username.substring(0, 2).toUpperCase();
    }
    return email.substring(0, 2).toUpperCase();
  }

  // Role checking methods
  bool get isAdmin => role == UserRole.admin;
  bool get isUser => role == UserRole.user;

  // Get role display name
  String get roleDisplayName => role.displayName;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, username: $username, role: ${role.value}, contacts: ${contacts.length}, addresses: ${addresses.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
} 