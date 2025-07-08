class Product {
  final String? id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final bool isChilled;
  final String category;

  const Product({
    this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    this.isChilled = false,
    this.category = 'General',
  });

  // Convert Product to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'price': price,
      'isChilled': isChilled,
      'category': category,
      'createdAt': DateTime.now().toIso8601String(),
      'available': true,
    };
  }

  // Create Product from Firestore document
  factory Product.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Product(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      isChilled: data['isChilled'] ?? false,
      category: data['category'] ?? 'General',
    );
  }

  // Create a copy of Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    bool? isChilled,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      isChilled: isChilled ?? this.isChilled,
      category: category ?? this.category,
    );
  }
} 