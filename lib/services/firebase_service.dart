import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../models/product_model.dart';
import '../models/transaction_model.dart' as app;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Collection references
  CollectionReference get _productsCollection => _firestore.collection('products');
  CollectionReference get _categoriesCollection => _firestore.collection('categories');
  CollectionReference get _transactionsCollection => _firestore.collection('transactions');

  // GET: Stream semua products (Real-time)
  Stream<List<Product>> getProducts() {
    return _productsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  // GET: Stream products by category (Real-time)
  Stream<List<Product>> getProductsByCategory(String category) {
    return _productsCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  // GET: Future semua products (One-time fetch) with timeout
  Future<List<Product>> getProductsOnce() async {
    await _ensureAuthentication(allowGuest: true); // Allow guest access for reading
    try {
      final snapshot = await _productsCollection
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Firestore get timeout after 10 seconds');
          });
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      log('Error getting products: $e');
      return [];
    }
  }

  // COMPRESS: Compress image and convert to base64
  Future<String?> compressImageToBase64(File imageFile) async {
    try {
      log('Starting image compression to base64...');
      
      // Read image file
      final imageBytes = await imageFile.readAsBytes();
      log('Original image size: ${imageBytes.length} bytes');
      
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        log('Failed to decode image');
        return null;
      }
      
      // Resize image for Firestore (max 300x300 to keep under 1MB limit)
      img.Image resizedImage = image;
      if (image.width > 300 || image.height > 300) {
        resizedImage = img.copyResize(image, width: 300, height: 300);
        log('Image resized to ${resizedImage.width}x${resizedImage.height}');
      }
      
      // Compress image (quality 70 for smaller size)
      final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
      log('Compressed image size: ${compressedBytes.length} bytes');
      
      // Convert to base64
      final base64String = base64Encode(compressedBytes);
      log('Base64 string length: ${base64String.length} characters');
      
      // Check if size is reasonable for Firestore (under 1MB)
      if (base64String.length > 1000000) { // ~1MB limit
        log('Warning: Base64 string too large (${base64String.length} chars)');
        return null;
      }
      
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      log('Error compressing image to base64: $e');
      return null;
    }
  }

  // COMPRESS: Compress image before upload (legacy method)
  Future<Uint8List?> compressImage(File imageFile) async {
    try {
      log('Starting image compression...');
      
      // Read image file
      final imageBytes = await imageFile.readAsBytes();
      log('Original image size: ${imageBytes.length} bytes');
      
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        log('Failed to decode image');
        return null;
      }
      
      // Resize image if too large (max 800x800)
      img.Image resizedImage = image;
      if (image.width > 800 || image.height > 800) {
        resizedImage = img.copyResize(image, width: 800, height: 800);
        log('Image resized to ${resizedImage.width}x${resizedImage.height}');
      }
      
      // Compress image (quality 85)
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      log('Compressed image size: ${compressedBytes.length} bytes');
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      log('Error compressing image: $e');
      return null;
    }
  }

  // UPLOAD: Upload image to Firebase Storage with compression & timeout
  Future<String?> uploadProductImage(File imageFile, String productName) async {
    try {
      log('Starting image upload process...');
      
      // Compress image first
      final compressedBytes = await compressImage(imageFile);
      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }
      
      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${productName}_$timestamp.jpg'.replaceAll(' ', '_');
      
      // Create reference to Firebase Storage
      final ref = _storage.ref().child('product_images/$fileName');
      
      // Upload compressed image with timeout
      final uploadTask = ref.putData(compressedBytes);
      
      // Wait for upload to complete with timeout (30 seconds)
      final snapshot = await uploadTask.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          uploadTask.cancel();
          throw Exception('Upload timeout after 30 seconds');
        },
      );
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      log('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      log('Error uploading image: $e');
      return null;
    }
  }

  // Check and ensure user authentication (guest mode allowed for read operations)
  Future<void> _ensureAuthentication({bool allowGuest = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !allowGuest) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        log('✅ Anonymous authentication successful for Firebase operations');
      } catch (e) {
        log('❌ Anonymous authentication failed: $e');
        // Don't throw error, allow guest access for some operations
        log('⚠️ Continuing without authentication (guest mode)');
      }
    }
  }

  // POST: Add new product with base64 image (no Firebase Storage needed)
  Future<String?> addProduct(Product product, {File? imageFile}) async {
    await _ensureAuthentication(allowGuest: false); // Require authentication for adding
    try {
      log('Starting add product process...');
      String? imageUrl = product.imageUrl;
      
      // Convert image to base64 if provided
      if (imageFile != null) {
        log('Converting image to base64...');
        imageUrl = await compressImageToBase64(imageFile);
        if (imageUrl == null) {
          // Fallback: Save product without image
          log('Image conversion failed, saving product without image');
          imageUrl = ''; // Empty string for no image
        } else {
          log('Image successfully converted to base64');
        }
      }
      
      // Create product with base64 image URL (bisa empty string jika gagal)
      final productWithImage = product.copyWith(imageUrl: imageUrl);
      
      // Add to Firestore with timeout
      log('Adding product to Firestore...');
      final docRef = await _productsCollection
          .add(productWithImage.toFirestore())
          .timeout(Duration(seconds: 15), onTimeout: () {
            throw Exception('Firestore add timeout after 15 seconds');
          });
      
      log('Product added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      log('Error adding product: $e');
      
      // Throw specific error message untuk UI handling
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied - check Firestore rules');
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception('Network error - check internet connection');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Request timeout - try again');
      } else if (e.toString().contains('document-too-large')) {
        throw Exception('Image too large - try smaller image');
      } else {
        throw Exception('Firebase error: ${e.toString()}');
      }
    }
  }

  // PUT: Update product with timeout
  Future<bool> updateProduct(String productId, Product product) async {
    try {
      await _productsCollection
          .doc(productId)
          .update(product.toFirestore())
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Firestore update timeout after 10 seconds');
          });
      log('Product updated successfully');
      return true;
    } catch (e) {
      log('Error updating product: $e');
      return false;
    }
  }

  // DELETE: Delete product with timeout
  Future<bool> deleteProduct(String productId) async {
    try {
      await _productsCollection
          .doc(productId)
          .delete()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Firestore delete timeout after 10 seconds');
          });
      log('Product deleted successfully');
      return true;
    } catch (e) {
      log('Error deleting product: $e');
      return false;
    }
  }

  // GET: Get categories with timeout
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _categoriesCollection
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Firestore get categories timeout after 10 seconds');
          });
      if (snapshot.docs.isEmpty) {
        // Return default categories if none exist
        return ['Popular', 'Cookies', 'Martabak', 'Terangbulan'];
      }
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      log('Error getting categories: $e');
      return ['Popular', 'Cookies', 'Martabak', 'Terangbulan']; // Default categories
    }
  }

  // UTILITY: Initialize sample data ke Firestore
  Future<void> initializeSampleData() async {
    try {
      // Check if data already exists
      final snapshot = await _productsCollection.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        log('Products already exist in Firestore, skipping initialization');
        return;
      }

      log('Initializing sample data to Firestore...');

      // Sample products data for Sinum
      final sampleProducts = [
        // Cookies
        Product(
          name: 'Chocolate Peanut Butter Brownie',
          description: 'Brownies cokelat dengan selai kacang yang lezat',
          price: 35000,
          imageUrl: 'assets/images/cookies/964fefc4-77ce-4f56-bde6-064d181822d4_ChocolatePeanutButterBrownie_LTO_FlyingAerial_TECH.png',
          category: 'Cookies',
        ),
        Product(
          name: 'French Toast Delight',
          description: 'Roti panggang ala Prancis dengan sirup maple',
          price: 28000,
          imageUrl: 'assets/images/cookies/46bf1e33-f9bf-40ce-be5e-f02de5d47146_FrenchToast_FlyingAerial_TECH.png',
          category: 'Cookies',
        ),
        Product(
          name: 'Chocolate Chip Cookies',
          description: 'Cookies cokelat chip yang renyah dan manis',
          price: 25000,
          imageUrl: 'assets/images/cookies/6c54f810-416b-4266-a628-fc00b5d4ed49_MilkChocolateChip_FlyingAerial_TECH.png',
          category: 'Cookies',
        ),
        Product(
          name: 'Smores Delight',
          description: 'Kombinasi marshmallow, cokelat, dan graham cracker',
          price: 32000,
          imageUrl: 'assets/images/cookies/ce1deb6c-c43d-434f-890a-d5d12d4de95b_Smores_FlyingAerial_TECH.png',
          category: 'Cookies',
        ),
        // Martabak
        Product(
          name: 'Martabak Ayam',
          description: 'Martabak telur dengan isian ayam yang gurih',
          price: 15000,
          imageUrl: 'assets/images/martabak/Martabak_ayam.jpeg',
          category: 'Martabak',
        ),
        Product(
          name: 'Martabak Daging',
          description: 'Martabak telur dengan isian daging sapi cincang',
          price: 18000,
          imageUrl: 'assets/images/martabak/Martabak_daging.jpeg',
          category: 'Martabak',
        ),
        Product(
          name: 'Martabak Sayur',
          description: 'Martabak telur dengan isian sayuran segar',
          price: 12000,
          imageUrl: 'assets/images/martabak/Martabak_sayur.jpeg',
          category: 'Martabak',
        ),
        Product(
          name: 'Martabak Telur',
          description: 'Martabak telur klasik dengan bumbu tradisional',
          price: 10000,
          imageUrl: 'assets/images/martabak/Martabak_telur.jpeg',
          category: 'Martabak',
        ),
      ];

      // Add sample products to Firestore
      for (final product in sampleProducts) {
        await addProduct(product);
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay
      }

      log('✅ Sample data initialized successfully to Firestore!');
    } catch (e) {
      log('❌ Error initializing sample data: $e');
    }
  }

  // UTILITY: Clear all products (for testing)
  Future<void> clearAllProducts() async {
    try {
      final snapshot = await _productsCollection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      log('All products cleared successfully');
    } catch (e) {
      log('Error clearing products: $e');
    }
  }

  // ============ TRANSACTION METHODS ============

  // POST: Create new transaction
  Future<String?> createTransaction(app.Transaction transaction) async {
    await _ensureAuthentication(allowGuest: false); // Require authentication
    try {
      log('🔥 FIREBASE: Creating new transaction...');
      log('📋 User ID: ${transaction.userId}');
      log('📝 Items count: ${transaction.items.length}');
      log('💰 Total amount: ${transaction.totalAmount}');
      
      final firestoreData = transaction.toFirestore();
      log('📄 Firestore data prepared: ${firestoreData.keys.join(', ')}');
      
      final docRef = await _transactionsCollection
          .add(firestoreData)
          .timeout(Duration(seconds: 15), onTimeout: () {
            log('❌ FIREBASE: Transaction creation timeout after 15 seconds');
            throw Exception('Transaction creation timeout after 15 seconds');
          });
      
      log('✅ FIREBASE: Transaction created successfully with ID: ${docRef.id}');
      
      // Verify the transaction was saved correctly
      final savedDoc = await docRef.get();
      if (savedDoc.exists) {
        log('✅ FIREBASE: Transaction verification successful');
        final savedData = savedDoc.data() as Map<String, dynamic>;
        log('📊 FIREBASE: Saved transaction userId: ${savedData['userId']}');
        log('📊 FIREBASE: Saved transaction total: ${savedData['totalAmount']}');
      } else {
        log('❌ FIREBASE: Transaction verification failed - document does not exist');
      }
      
      return docRef.id;
    } catch (e) {
      log('❌ FIREBASE: Error creating transaction: $e');
      log('❌ FIREBASE: Error type: ${e.runtimeType}');
      
      if (e.toString().contains('permission-denied')) {
        log('❌ FIREBASE: Permission denied error');
        throw Exception('Permission denied - check Firestore rules');
      } else if (e.toString().contains('network-request-failed')) {
        log('❌ FIREBASE: Network error');
        throw Exception('Network error - check internet connection');
      } else if (e.toString().contains('timeout')) {
        log('❌ FIREBASE: Timeout error');
        throw Exception('Request timeout - try again');
      } else {
        log('❌ FIREBASE: Unknown error: ${e.toString()}');
        throw Exception('Firebase error: ${e.toString()}');
      }
    }
  }

  // GET: Get user transactions
  Future<List<app.Transaction>> getUserTransactions(String userId) async {
    await _ensureAuthentication(allowGuest: true);
    try {
      log('🔥 FIREBASE: Getting user transactions for userId: $userId');
      
      final snapshot = await _transactionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            log('❌ FIREBASE: Get transactions timeout after 10 seconds');
            throw Exception('Get transactions timeout after 10 seconds');
          });
      
      log('📊 FIREBASE: Found ${snapshot.docs.length} transaction documents');
      
      final transactions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        log('📄 FIREBASE: Processing transaction ${doc.id}');
        log('📊 FIREBASE: Transaction data keys: ${data.keys.join(', ')}');
        return app.Transaction.fromFirestore(data, doc.id);
      }).toList();
      
      log('✅ FIREBASE: Successfully parsed ${transactions.length} transactions');
      for (var transaction in transactions) {
        log('  - ${transaction.transactionNumber}: ${transaction.totalAmount} (${transaction.status.displayName})');
      }
      
      return transactions;
    } catch (e) {
      log('❌ FIREBASE: Error getting user transactions: $e');
      log('❌ FIREBASE: Error type: ${e.runtimeType}');
      return [];
    }
  }

  // GET: Stream user transactions (Real-time)
  Stream<List<app.Transaction>> getUserTransactionsStream(String userId) {
    return _transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app.Transaction.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  // GET: Get all transactions (Admin only)
  Future<List<app.Transaction>> getAllTransactions() async {
    await _ensureAuthentication(allowGuest: true);
    try {
      final snapshot = await _transactionsCollection
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Get all transactions timeout after 10 seconds');
          });
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app.Transaction.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      log('Error getting all transactions: $e');
      return [];
    }
  }

  // GET: Stream all transactions (Admin only - Real-time)
  Stream<List<app.Transaction>> getAllTransactionsStream() {
    return _transactionsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app.Transaction.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  // PUT: Update transaction status
  Future<bool> updateTransactionStatus(String transactionId, app.TransactionStatus status) async {
    try {
      final updateData = {
        'status': status.value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Add deliveredAt if status is delivered
      if (status == app.TransactionStatus.delivered) {
        updateData['deliveredAt'] = Timestamp.fromDate(DateTime.now());
      }

      await _transactionsCollection
          .doc(transactionId)
          .update(updateData)
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Update transaction status timeout after 10 seconds');
          });
      
      log('Transaction status updated successfully');
      return true;
    } catch (e) {
      log('Error updating transaction status: $e');
      return false;
    }
  }

  // GET: Get transaction by ID
  Future<app.Transaction?> getTransactionById(String transactionId) async {
    try {
      final doc = await _transactionsCollection
          .doc(transactionId)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Get transaction timeout after 10 seconds');
          });
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return app.Transaction.fromFirestore(data, doc.id);
      }
      return null;
    } catch (e) {
      log('Error getting transaction by ID: $e');
      return null;
    }
  }

  // DELETE: Cancel transaction (if allowed)
  Future<bool> cancelTransaction(String transactionId) async {
    try {
      await _transactionsCollection
          .doc(transactionId)
          .update({
            'status': app.TransactionStatus.cancelled.value,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          })
          .timeout(Duration(seconds: 10), onTimeout: () {
            throw Exception('Cancel transaction timeout after 10 seconds');
          });
      
      log('Transaction cancelled successfully');
      return true;
    } catch (e) {
      log('Error cancelling transaction: $e');
      return false;
    }
  }

  // UTILITY: Get transaction statistics
  Future<Map<String, dynamic>> getTransactionStatistics() async {
    try {
      final snapshot = await _transactionsCollection.get();
      
      int totalTransactions = snapshot.docs.length;
      double totalRevenue = 0;
      Map<String, int> statusCounts = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final transaction = app.Transaction.fromFirestore(data, doc.id);
        
        totalRevenue += transaction.totalAmount;
        
        final status = transaction.status.value;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      return {
        'totalTransactions': totalTransactions,
        'totalRevenue': totalRevenue,
        'statusCounts': statusCounts,
      };
    } catch (e) {
      log('Error getting transaction statistics: $e');
      return {
        'totalTransactions': 0,
        'totalRevenue': 0.0,
        'statusCounts': <String, int>{},
      };
    }
  }
} 