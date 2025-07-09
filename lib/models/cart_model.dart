import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String productId;
  final String productName;
  final String productImageUrl;
  final double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

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

  factory CartItem.fromFirestore(Map<String, dynamic> data) {
    return CartItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImageUrl: data['productImageUrl'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
    );
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    String? productImageUrl,
    double? price,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() {
    return 'CartItem(productId: $productId, productName: $productName, quantity: $quantity, subtotal: $subtotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;
}

class Cart {
  final String? id;
  final String userId;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cart({
    this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculated properties
  double get totalAmount => items.fold(0, (total, item) => total + item.subtotal);
  int get totalItems => items.fold(0, (total, item) => total + item.quantity);
  int get totalProducts => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  // Convert Cart to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toFirestore()).toList(),
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'totalProducts': totalProducts,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create Cart from Firestore document
  factory Cart.fromFirestore(Map<String, dynamic> data, String docId) {
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => CartItem.fromFirestore(item as Map<String, dynamic>))
        .toList();

    return Cart(
      id: docId,
      userId: data['userId'] ?? '',
      items: items,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create empty cart for a user
  factory Cart.empty(String userId) {
    final now = DateTime.now();
    return Cart(
      userId: userId,
      items: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  // Create a copy of Cart with updated fields
  Cart copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Add item to cart
  Cart addItem(CartItem newItem) {
    final updatedItems = List<CartItem>.from(items);
    
    // Check if item already exists
    final existingIndex = updatedItems.indexWhere(
      (item) => item.productId == newItem.productId,
    );

    if (existingIndex >= 0) {
      // Update quantity if item exists
      final existingItem = updatedItems[existingIndex];
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + newItem.quantity,
      );
    } else {
      // Add new item
      updatedItems.add(newItem);
    }

    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );
  }

  // Remove item from cart
  Cart removeItem(String productId) {
    final updatedItems = items.where((item) => item.productId != productId).toList();
    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );
  }

  // Update item quantity
  Cart updateItemQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(productId);
    }

    final updatedItems = items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();

    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );
  }

  // Clear all items from cart
  Cart clear() {
    return copyWith(
      items: [],
      updatedAt: DateTime.now(),
    );
  }

  // Get item by product ID
  CartItem? getItem(String productId) {
    try {
      return items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  // Check if product exists in cart
  bool hasProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  // Get quantity of specific product
  int getProductQuantity(String productId) {
    final item = getItem(productId);
    return item?.quantity ?? 0;
  }

  @override
  String toString() {
    return 'Cart(id: $id, userId: $userId, totalItems: $totalItems, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cart && other.id == id && other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(id, userId);
} 