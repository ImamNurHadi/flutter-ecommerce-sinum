import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../models/product_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Collection references
  CollectionReference get _productsCollection => _firestore.collection('products');
  CollectionReference get _categoriesCollection => _firestore.collection('categories');

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
} 