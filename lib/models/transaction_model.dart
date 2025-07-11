import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus {
  processing('processing'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled');

  const TransactionStatus(this.value);
  final String value;

  static TransactionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'processing':
        return TransactionStatus.processing;
      case 'shipped':
        return TransactionStatus.shipped;
      case 'delivered':
        return TransactionStatus.delivered;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.processing; // Default changed to processing
    }
  }

  String get displayName {
    switch (this) {
      case TransactionStatus.processing:
        return 'Diproses';
      case TransactionStatus.shipped:
        return 'Dalam Pengiriman';
      case TransactionStatus.delivered:
        return 'Selesai';
      case TransactionStatus.cancelled:
        return 'Dibatalkan';
    }
  }
}

class TransactionItem {
  final String productId;
  final String productName;
  final String productImageUrl;
  final double price;
  final int quantity;
  final double subtotal;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory TransactionItem.fromFirestore(Map<String, dynamic> data) {
    return TransactionItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImageUrl: data['productImageUrl'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 0,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'TransactionItem(productId: $productId, productName: $productName, quantity: $quantity, subtotal: $subtotal)';
  }
}

class Transaction {
  final String? id;
  final String userId;
  final String userName;
  final String userEmail;
  final List<TransactionItem> items;
  final double totalAmount;
  final TransactionStatus status;
  final String? deliveryAddress;
  final String? phoneNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;

  const Transaction({
    this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.items,
    required this.totalAmount,
    this.status = TransactionStatus.processing,
    this.deliveryAddress,
    this.phoneNumber,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
  });

  // Convert Transaction to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'items': items.map((item) => item.toFirestore()).toList(),
      'totalAmount': totalAmount,
      'status': status.value,
      'deliveryAddress': deliveryAddress,
      'phoneNumber': phoneNumber,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    };
  }

  // Create Transaction from Firestore document
  factory Transaction.fromFirestore(Map<String, dynamic> data, String docId) {
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => TransactionItem.fromFirestore(item as Map<String, dynamic>))
        .toList();

    return Transaction(
      id: docId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      items: items,
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: TransactionStatus.fromString(data['status'] ?? 'processing'),
      deliveryAddress: data['deliveryAddress'],
      phoneNumber: data['phoneNumber'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  // Create a copy of Transaction with updated fields
  Transaction copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    List<TransactionItem>? items,
    double? totalAmount,
    TransactionStatus? status,
    String? deliveryAddress,
    String? phoneNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveredAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  // Helper methods
  int get totalItems => items.fold(0, (total, item) => total + item.quantity);
  
  bool get isPending => status == TransactionStatus.processing;
  bool get isProcessing => status == TransactionStatus.processing;
  bool get isShipped => status == TransactionStatus.shipped;
  bool get isDelivered => status == TransactionStatus.delivered;
  bool get isCancelled => status == TransactionStatus.cancelled;
  bool get isCompleted => status == TransactionStatus.delivered;

  String get statusDisplayName => status.displayName;

  // Generate transaction number
  String get transactionNumber {
    if (id == null) return 'TXN-UNKNOWN';
    final date = createdAt.toString().substring(0, 10).replaceAll('-', '');
    final shortId = id!.length > 8 ? id!.substring(0, 8).toUpperCase() : id!.toUpperCase();
    return 'TXN-$date-$shortId';
  }

  @override
  String toString() {
    return 'Transaction(id: $id, userId: $userId, totalAmount: $totalAmount, status: ${status.value}, itemCount: ${items.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 