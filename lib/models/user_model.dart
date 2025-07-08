class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? address;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.address,
    this.phoneNumber,
    this.profileImageUrl,
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
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      address: data['address'],
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
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
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username,
      address: address,
      phoneNumber: phoneNumber,
      profileImageUrl: profileImageUrl,
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
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // Check if user has complete profile
  bool get isProfileComplete {
    return username.isNotEmpty && email.isNotEmpty;
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

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, username: $username, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
} 