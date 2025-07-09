import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sinum/screens/product_detail_screen.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  Future<bool> _isAdminUser() async {
    try {
      final authService = AuthService();
      final currentUser = await authService.getCurrentUserData();
      return currentUser?.isAdmin ?? false;
    } catch (e) {
      return false;
    }
  }

  static Widget buildProductImage(Product product) {
    try {
      // Debug print
      print('ProductCard: imageUrl type: ${product.imageUrl.runtimeType}');
      print('ProductCard: imageUrl length: ${product.imageUrl.length}');
      print('ProductCard: imageUrl starts with: ${product.imageUrl.length > 50 ? product.imageUrl.substring(0, 50) : product.imageUrl}...');
      
      // Check if imageUrl is base64 data
      if (product.imageUrl.isNotEmpty && product.imageUrl.startsWith('data:image/')) {
        try {
          final base64Data = product.imageUrl.split(',')[1];
          final bytes = base64Decode(base64Data);
          print('ProductCard: Base64 decoded successfully, bytes length: ${bytes.length}');
          
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 110,
            errorBuilder: (context, error, stackTrace) {
              print('ProductCard: Image.memory error: $error');
              return _buildPlaceholderImageStatic();
            },
          );
        } catch (e) {
          print('ProductCard: Base64 decode error: $e');
          return _buildPlaceholderImageStatic();
        }
      }
      // Check if imageUrl is asset path
      else if (product.imageUrl.startsWith('assets/')) {
        return Image.asset(
          product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 110,
          errorBuilder: (context, error, stackTrace) {
            print('ProductCard: Image.asset error: $error');
            return _buildPlaceholderImageStatic();
          },
        );
      }
      // Check if imageUrl is network URL
      else if (product.imageUrl.startsWith('http')) {
        return Image.network(
          product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 110,
          errorBuilder: (context, error, stackTrace) {
            print('ProductCard: Image.network error: $error');
            return _buildPlaceholderImageStatic();
          },
        );
      }
      // Default placeholder for empty or invalid imageUrl
      else {
        print('ProductCard: Using placeholder - imageUrl: "${product.imageUrl}"');
        return _buildPlaceholderImageStatic();
      }
    } catch (e) {
      print('ProductCard: General error in buildProductImage: $e');
      return _buildPlaceholderImageStatic();
    }
  }

  static Widget _buildPlaceholderImageStatic() {
    return Container(
      color: Colors.grey[50],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fastfood,
            size: 30,
            color: Color(0xFFFF6B35),
          ),
          SizedBox(height: 4),
          Text(
            'Food Image',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    try {
      // Debug print
      print('ProductCard: imageUrl type: ${product.imageUrl.runtimeType}');
      print('ProductCard: imageUrl length: ${product.imageUrl.length}');
      print('ProductCard: imageUrl starts with: ${product.imageUrl.length > 50 ? product.imageUrl.substring(0, 50) : product.imageUrl}...');
      
      // Check if imageUrl is base64 data
      if (product.imageUrl.isNotEmpty && product.imageUrl.startsWith('data:image/')) {
        try {
          final base64Data = product.imageUrl.split(',')[1];
          final bytes = base64Decode(base64Data);
          print('ProductCard: Base64 decoded successfully, bytes length: ${bytes.length}');
          
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 110,
            errorBuilder: (context, error, stackTrace) {
              print('ProductCard: Image.memory error: $error');
              return _buildPlaceholderImage();
            },
          );
        } catch (e) {
          print('ProductCard: Base64 decode error: $e');
          return _buildPlaceholderImage();
        }
      }
      // Check if imageUrl is asset path
      else if (product.imageUrl.startsWith('assets/')) {
        return Image.asset(
          product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 110,
          errorBuilder: (context, error, stackTrace) {
            print('ProductCard: Image.asset error: $error');
            return _buildPlaceholderImage();
          },
        );
      }
      // Check if imageUrl is network URL
      else if (product.imageUrl.startsWith('http')) {
        return Image.network(
          product.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 110,
          errorBuilder: (context, error, stackTrace) {
            print('ProductCard: Image.network error: $error');
            return _buildPlaceholderImage();
          },
        );
      }
      // Default placeholder for empty or invalid imageUrl
      else {
        print('ProductCard: Using placeholder - imageUrl: "${product.imageUrl}"');
        return _buildPlaceholderImage();
      }
    } catch (e) {
      print('ProductCard: General error in _buildProductImage: $e');
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[50],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fastfood,
            size: 30,
            color: Color(0xFFFF6B35),
          ),
          SizedBox(height: 4),
          Text(
            'Food Image',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image
          SizedBox(
            height: 110,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(product: product),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: _buildProductImage(),
                    ),
                  ),
                  // Category Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Heart Icon
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: Color(0xFFFF6B35),
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Product Info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Product Description
                Text(
                  product.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Price
                Text(
                  currencyFormatter.format(product.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(height: 6),
                // Add to Cart Button (Only show for non-admin users)
                FutureBuilder<bool>(
                  future: _isAdminUser(),
                  builder: (context, snapshot) {
                    final isAdmin = snapshot.data ?? false;
                    
                    if (isAdmin) {
                      // Show View Details button for admin
                      return SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          child: const Text(
                            'Lihat Detail',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Show Add to Cart button for regular users
                      return SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final authService = AuthService();
                              final cartService = CartService();
                              
                              // Get current user
                              final currentUser = await authService.getCurrentUserData();
                              
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan login terlebih dahulu'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                Navigator.pushNamed(context, '/login');
                                return;
                              }
                              
                              // Add item to cart
                              final success = await cartService.addItemToCart(
                                currentUser.uid,
                                product,
                                quantity: 1,
                              );
                              
                              if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                                    content: Text('${product.name} ditambahkan ke keranjang!'),
                          backgroundColor: const Color(0xFFFF6B35),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Gagal menambahkan ke keranjang'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 