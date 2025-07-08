import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  
  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  
  late String _selectedCategory;
  late bool _isChilled;
  bool _isLoading = false;
  String _loadingMessage = 'Mengupdate produk...';
  
  // Image picker
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = ['Cookies', 'Martabak', 'Terangbulan'];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing product data
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _selectedCategory = widget.product.category;
    _isChilled = widget.product.isChilled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    // Check authentication (improved handling)
    final user = FirebaseAuth.instance.currentUser;
    print('🔍 Current user: ${user?.uid ?? 'null'}');
    
    if (user == null) {
      print('⚠️ User not authenticated, trying to sign in anonymously...');
      try {
        await FirebaseAuth.instance.signInAnonymously();
        print('✅ Anonymous sign in successful');
      } catch (e) {
        print('❌ Anonymous sign in failed: $e');
        // Check again if user is available despite error
        final retryUser = FirebaseAuth.instance.currentUser;
        if (retryUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Gagal autentikasi: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        } else {
          print('✅ User found after retry: ${retryUser.uid}');
        }
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Memproses update...';
    });

    try {
      // Update loading message
      setState(() {
        _loadingMessage = 'Memproses gambar...';
      });
      
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UI
      
      // Create updated product with existing or new image
      String imageUrl = widget.product.imageUrl; // Keep existing image by default
      
      // If new image is selected, process it
      if (_selectedImage != null) {
        setState(() {
          _loadingMessage = 'Mengkompres gambar baru...';
        });
        
        // Convert new image to base64
        final base64Image = await _firebaseService.compressImageToBase64(_selectedImage!);
        if (base64Image != null) {
          imageUrl = base64Image;
        } else {
          print('Failed to process new image, keeping existing image');
        }
      }
      
      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        imageUrl: imageUrl,
        category: _selectedCategory,
        isChilled: _isChilled,
      );

      setState(() {
        _loadingMessage = 'Menyimpan ke database...';
      });

      final success = await _firebaseService.updateProduct(widget.product.id!, updatedProduct);
      
      await Future.delayed(const Duration(milliseconds: 300)); // Small delay for UI
      
      if (success) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Produk berhasil diupdate!'),
            backgroundColor: Color(0xFFFF6B35),
            duration: Duration(seconds: 2),
          ),
        );

        // Go back
        Navigator.pop(context, true); // Return true untuk refresh list
      } else {
        throw Exception('Gagal mengupdate produk');
      }
    } catch (e) {
      String errorMessage = 'Terjadi kesalahan yang tidak diketahui';
      
      print('Update product error: $e'); // Debug print
      
      if (e.toString().contains('Permission denied') || e.toString().contains('permission-denied')) {
        errorMessage = 'Tidak memiliki izin - periksa konfigurasi Firebase';
      } else if (e.toString().contains('timeout') || e.toString().contains('Request timeout')) {
        errorMessage = 'Koneksi timeout - periksa koneksi internet Anda';
      } else if (e.toString().contains('network') || e.toString().contains('Network error')) {
        errorMessage = 'Masalah jaringan - periksa koneksi internet Anda';
      } else if (e.toString().contains('document-too-large')) {
        errorMessage = 'Gambar terlalu besar - coba dengan gambar yang lebih kecil';
      } else {
        errorMessage = 'Firebase error: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Coba Lagi',
            textColor: Colors.white,
            onPressed: () => _updateProduct(),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _loadingMessage = 'Mengupdate produk...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      onPopInvoked: (didPop) {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Tunggu hingga proses selesai...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Produk',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.edit,
                      size: 48,
                      color: Color(0xFFFF6B35),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Edit Produk',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update informasi produk "${widget.product.name}"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form Fields
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Produk
                    const Text(
                      'Nama Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Martabak Ayam Spesial',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama produk tidak boleh kosong';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Deskripsi
                    const Text(
                      'Deskripsi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Deskripsikan produk Anda...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Deskripsi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Harga
                    const Text(
                      'Harga (Rp)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 15000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Harga harus berupa angka';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Kategori
                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Current & New Image
                    const Text(
                      'Gambar Produk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Current Image Preview
                    if (_selectedImage == null) ...[
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: widget.product.imageUrl.isNotEmpty 
                              ? (widget.product.imageUrl.startsWith('data:image/')
                                  ? Image.memory(
                                      base64Decode(widget.product.imageUrl.split(',')[1]),
                                      fit: BoxFit.cover,
                                    )
                                  : widget.product.imageUrl.startsWith('assets/')
                                      ? Image.asset(widget.product.imageUrl, fit: BoxFit.cover)
                                      : Image.network(widget.product.imageUrl, fit: BoxFit.cover))
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image, size: 48, color: Colors.grey),
                                      Text('Gambar saat ini', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF6B35)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.edit, color: Color(0xFFFF6B35)),
                          label: const Text(
                            'Ganti Gambar',
                            style: TextStyle(color: Color(0xFFFF6B35)),
                          ),
                        ),
                      ),
                    ],
                    
                    // New Image Preview
                    if (_selectedImage != null) ...[
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImage,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF6B35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.edit, color: Color(0xFFFF6B35)),
                              label: const Text(
                                'Ganti Lagi',
                                style: TextStyle(color: Color(0xFFFF6B35)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.cancel, color: Colors.grey),
                              label: const Text(
                                'Batal',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Checkbox Chilled
                    Row(
                      children: [
                        Checkbox(
                          value: _isChilled,
                          activeColor: const Color(0xFFFF6B35),
                          onChanged: (value) {
                            setState(() {
                              _isChilled = value ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Produk perlu didinginkan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Update Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(_loadingMessage),
                          ],
                        )
                      : const Text(
                          'Update Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
    );
  }
} 