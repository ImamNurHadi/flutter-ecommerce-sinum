import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection reference
  CollectionReference get _cartCollection => _firestore.collection('carts');

  // GET: Get user cart
  Future<Cart?> getUserCart(String userId) async {
    try {
      final querySnapshot = await _cartCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Get cart timeout after 10 seconds');
          });

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        return Cart.fromFirestore(data, doc.id);
      }

      // Return empty cart if not found
      return Cart.empty(userId);
    } catch (e) {
      log('Error getting user cart: $e');
      return Cart.empty(userId);
    }
  }

  // GET: Stream user cart (Real-time)
  Stream<Cart> getUserCartStream(String userId) {
    return _cartCollection
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        return Cart.fromFirestore(data, doc.id);
      }
      return Cart.empty(userId);
    });
  }

  // POST/PUT: Save cart to Firestore
  Future<bool> saveCart(Cart cart) async {
    try {
      if (cart.id != null) {
        // Update existing cart
        await _cartCollection
            .doc(cart.id)
            .update(cart.toFirestore())
            .timeout(Duration(seconds: 10), onTimeout: () {
              throw Exception('Update cart timeout after 10 seconds');
            });
      } else {
        // Create new cart
        await _cartCollection
            .add(cart.toFirestore())
            .timeout(Duration(seconds: 10), onTimeout: () {
              throw Exception('Create cart timeout after 10 seconds');
            });
      }
      
      log('Cart saved successfully');
      return true;
    } catch (e) {
      log('Error saving cart: $e');
      return false;
    }
  }

  // ADD: Add item to cart
  Future<bool> addItemToCart(String userId, Product product, {int quantity = 1}) async {
    try {
      // Get current cart
      Cart currentCart = await getUserCart(userId) ?? Cart.empty(userId);

      // Create cart item from product
      final cartItem = CartItem(
        productId: product.id ?? '',
        productName: product.name,
        productImageUrl: product.imageUrl,
        price: product.price,
        quantity: quantity,
      );

      // Add item to cart
      final updatedCart = currentCart.addItem(cartItem);

      // Save updated cart
      final success = await saveCart(updatedCart);
      
      if (success) {
        log('Item added to cart: ${product.name} x$quantity');
      }
      
      return success;
    } catch (e) {
      log('Error adding item to cart: $e');
      return false;
    }
  }

  // REMOVE: Remove item from cart
  Future<bool> removeItemFromCart(String userId, String productId) async {
    try {
      // Get current cart
      Cart currentCart = await getUserCart(userId) ?? Cart.empty(userId);

      // Remove item from cart
      final updatedCart = currentCart.removeItem(productId);

      // Save updated cart
      final success = await saveCart(updatedCart);
      
      if (success) {
        log('Item removed from cart: $productId');
      }
      
      return success;
    } catch (e) {
      log('Error removing item from cart: $e');
      return false;
    }
  }

  // UPDATE: Update item quantity in cart
  Future<bool> updateItemQuantity(String userId, String productId, int newQuantity) async {
    try {
      // Get current cart
      Cart currentCart = await getUserCart(userId) ?? Cart.empty(userId);

      // Update item quantity
      final updatedCart = currentCart.updateItemQuantity(productId, newQuantity);

      // Save updated cart
      final success = await saveCart(updatedCart);
      
      if (success) {
        log('Item quantity updated: $productId = $newQuantity');
      }
      
      return success;
    } catch (e) {
      log('Error updating item quantity: $e');
      return false;
    }
  }

  // CLEAR: Clear all items from cart
  Future<bool> clearCart(String userId) async {
    try {
      // Get current cart
      Cart currentCart = await getUserCart(userId) ?? Cart.empty(userId);

      // Clear all items
      final updatedCart = currentCart.clear();

      // Save updated cart
      final success = await saveCart(updatedCart);
      
      if (success) {
        log('Cart cleared for user: $userId');
      }
      
      return success;
    } catch (e) {
      log('Error clearing cart: $e');
      return false;
    }
  }

  // DELETE: Delete cart entirely
  Future<bool> deleteCart(String userId) async {
    try {
      final querySnapshot = await _cartCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      
      log('Cart deleted for user: $userId');
      return true;
    } catch (e) {
      log('Error deleting cart: $e');
      return false;
    }
  }

  // UTILITY: Get cart item count
  Future<int> getCartItemCount(String userId) async {
    try {
      final cart = await getUserCart(userId);
      return cart?.totalItems ?? 0;
    } catch (e) {
      log('Error getting cart item count: $e');
      return 0;
    }
  }

  // UTILITY: Get cart total amount
  Future<double> getCartTotalAmount(String userId) async {
    try {
      final cart = await getUserCart(userId);
      return cart?.totalAmount ?? 0.0;
    } catch (e) {
      log('Error getting cart total amount: $e');
      return 0.0;
    }
  }

  // UTILITY: Check if product is in cart
  Future<bool> isProductInCart(String userId, String productId) async {
    try {
      final cart = await getUserCart(userId);
      return cart?.hasProduct(productId) ?? false;
    } catch (e) {
      log('Error checking product in cart: $e');
      return false;
    }
  }

  // UTILITY: Get product quantity in cart
  Future<int> getProductQuantityInCart(String userId, String productId) async {
    try {
      final cart = await getUserCart(userId);
      return cart?.getProductQuantity(productId) ?? 0;
    } catch (e) {
      log('Error getting product quantity in cart: $e');
      return 0;
    }
  }

  // BATCH: Add multiple items to cart
  Future<bool> addMultipleItemsToCart(String userId, List<CartItem> items) async {
    try {
      // Get current cart
      Cart currentCart = await getUserCart(userId) ?? Cart.empty(userId);

      // Add all items
      Cart updatedCart = currentCart;
      for (final item in items) {
        updatedCart = updatedCart.addItem(item);
      }

      // Save updated cart
      final success = await saveCart(updatedCart);
      
      if (success) {
        log('Multiple items added to cart: ${items.length} items');
      }
      
      return success;
    } catch (e) {
      log('Error adding multiple items to cart: $e');
      return false;
    }
  }

  // UTILITY: Convert cart to transaction items
  List<dynamic> cartToTransactionItems(Cart cart) {
    return cart.items.map((item) => {
      'productId': item.productId,
      'productName': item.productName,
      'productImageUrl': item.productImageUrl,
      'price': item.price,
      'quantity': item.quantity,
      'subtotal': item.subtotal,
    }).toList();
  }

  // CLEANUP: Remove expired carts (older than 30 days)
  Future<void> cleanupExpiredCarts() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final expiredCarts = await _cartCollection
          .where('updatedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in expiredCarts.docs) {
        await doc.reference.delete();
      }
      
      log('Cleaned up ${expiredCarts.docs.length} expired carts');
    } catch (e) {
      log('Error cleaning up expired carts: $e');
    }
  }
} 