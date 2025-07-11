import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cart_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../screens/edit_profile_screen.dart'; // Added import for EditProfileScreen

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  
  UserModel? _currentUser;
  Cart? _userCart;
  bool _isLoading = true;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        final cart = await _cartService.getUserCart(userData.uid);
        setState(() {
          _currentUser = userData;
          _userCart = cart;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCart() async {
    if (_currentUser != null) {
      final cart = await _cartService.getUserCart(_currentUser!.uid);
      setState(() {
        _userCart = cart;
      });
    }
  }

  Future<void> _showDeleteConfirmationDialog(CartItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: Text(
            'Apakah Anda ingin menghapus "${item.productName}" dari keranjang?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (result == true && _currentUser != null) {
      await _cartService.removeItemFromCart(
        _currentUser!.uid,
        item.productId,
      );
      await _refreshCart();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productName} dihapus dari keranjang'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double get totalPrice => _userCart?.totalAmount ?? 0.0;
  List<CartItem> get cartItems => _userCart?.items ?? <CartItem>[];
  bool get isCartEmpty => cartItems.isEmpty;

  Future<void> _handleCheckout() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (isCartEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _showCheckoutDialog();
  }

  Future<void> _showCheckoutDialog() async {
    // Get user profile data
    final userData = await _authService.getCurrentUserData();
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User data not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user has contacts and addresses
    if (!userData.hasContactInfo || !userData.hasAddressInfo) {
      _showProfileSetupDialog(userData);
      return;
    }

    // Selected values
    String? selectedAddress;
    String? selectedPhone;
    
    // Set default values if available
    if (userData.defaultAddress != null) {
      selectedAddress = userData.defaultAddress!.address;
    }
    if (userData.defaultContact != null) {
      selectedPhone = userData.defaultContact!.phoneNumber;
    }

    final TextEditingController notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Konfirmasi Checkout'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alamat Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAddress,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Pilih alamat pengiriman'),
                        ),
                        isExpanded: true,
                        items: userData.addresses.map((address) {
                          return DropdownMenuItem<String>(
                            value: address.address,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.label,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    address.address,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedAddress = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Nomor Telepon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPhone,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Pilih nomor telepon'),
                        ),
                        isExpanded: true,
                        items: userData.contacts.map((contact) {
                          return DropdownMenuItem<String>(
                            value: contact.phoneNumber,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.label,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    contact.phoneNumber,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPhone = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Catatan (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      hintText: 'Catatan untuk penjual',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ringkasan Pesanan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...cartItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} x${item.quantity}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(item.price * item.quantity),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(totalPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedAddress == null || selectedPhone == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alamat dan nomor telepon wajib dipilih'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _processCheckout(
                  selectedAddress!,
                  selectedPhone!,
                  notesController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Konfirmasi Pesanan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSetupDialog(UserModel userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lengkapi Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sebelum checkout, harap lengkapi profile Anda terlebih dahulu:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (!userData.hasContactInfo)
              const Row(
                children: [
                  Icon(Icons.phone, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text('Tambahkan nomor telepon'),
                ],
              ),
            if (!userData.hasAddressInfo)
              const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text('Tambahkan alamat pengiriman'),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCheckout(String address, String phone, String notes) async {
    setState(() {
      _isCheckingOut = true;
    });

    try {
      debugPrint('🛒 CHECKOUT PROCESS STARTED');
      debugPrint('📋 User: ${_currentUser?.uid} (${_currentUser?.displayName})');
      debugPrint('📦 Cart items: ${_userCart?.items.length ?? 0}');
      debugPrint('💰 Total: $totalPrice');
      
      // Convert CartItem to TransactionItem using CartService
      final transactionItems = _cartService.cartToTransactionItems(_userCart!)
          .map((item) => TransactionItem(
            productId: item['productId'],
            productName: item['productName'],
            productImageUrl: item['productImageUrl'],
            price: item['price'].toDouble(),
            quantity: item['quantity'],
            subtotal: item['subtotal'].toDouble(),
          )).toList();

      debugPrint('📝 Transaction items created: ${transactionItems.length}');
      for (var item in transactionItems) {
        debugPrint('  - ${item.productName} x${item.quantity} = ${item.subtotal}');
      }

      // Create transaction
      final transaction = Transaction(
        userId: _currentUser!.uid,
        userName: _currentUser!.displayName,
        userEmail: _currentUser!.email,
        items: transactionItems,
        totalAmount: totalPrice,
        deliveryAddress: address,
        phoneNumber: phone,
        notes: notes.isNotEmpty ? notes : null,
        createdAt: DateTime.now(),
      );

      debugPrint('📄 Transaction object created');
      debugPrint('🔍 Transaction data preview: ${transaction.toFirestore().toString().substring(0, 200)}...');
      
      // Save to Firebase
      debugPrint('💾 Saving transaction to Firebase...');
      final transactionId = await _firebaseService.createTransaction(transaction);
      debugPrint('✅ Transaction saved with ID: $transactionId');

      if (transactionId != null) {
        debugPrint('🧹 Clearing cart from database...');
        await _cartService.clearCart(_currentUser!.uid);
        debugPrint('✅ Cart cleared successfully');
        
        // Refresh cart locally
        await _refreshCart();
        debugPrint('🔄 Cart refreshed locally');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint('🎯 Navigating to transaction history...');
        // Navigate to transaction history
        Navigator.pushReplacementNamed(context, '/transactions');
        debugPrint('✅ CHECKOUT PROCESS COMPLETED SUCCESSFULLY');
      } else {
        debugPrint('❌ Transaction ID is null - creation failed');
        throw Exception('Gagal membuat pesanan - ID transaksi kosong');
      }
    } catch (e) {
      debugPrint('❌ CHECKOUT ERROR: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat pesanan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCheckingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Cart',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D2D2D),
      ),
      body: cartItems.isEmpty ? _buildEmptyCart() : _buildCartContent(currencyFormatter),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add some delicious food to get started!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(NumberFormat currencyFormatter) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return Dismissible(
                key: Key(item.productId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onDismissed: (direction) async {
                  if (_currentUser != null) {
                    await _cartService.removeItemFromCart(
                      _currentUser!.uid,
                      item.productId,
                    );
                    await _refreshCart();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.productName} dihapus dari keranjang'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Item Image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          item.productImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.fastfood,
                              size: 40,
                              color: Color(0xFFFF6B35),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Item Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormatter.format(item.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Quantity Controls and Delete Button
                    Column(
                      children: [
                        // Delete Button
                        GestureDetector(
                          onTap: () async {
                            await _showDeleteConfirmationDialog(item);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                    // Quantity Controls
                    Row(
                      children: [
                        GestureDetector(
                              onTap: () async {
                                if (_currentUser != null) {
                            if (item.quantity > 1) {
                                    await _cartService.updateItemQuantity(
                                      _currentUser!.uid,
                                      item.productId,
                                      item.quantity - 1,
                                    );
                                    await _refreshCart();
                                  } else if (item.quantity == 1) {
                                    // Show confirmation dialog when quantity is 1
                                    await _showDeleteConfirmationDialog(item);
                                  }
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.remove, size: 18),
                          ),
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                              onTap: () async {
                                if (_currentUser != null) {
                                  await _cartService.updateItemQuantity(
                                    _currentUser!.uid,
                                    item.productId,
                                    item.quantity + 1,
                                  );
                                  await _refreshCart();
                                }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
        
        // Checkout Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  Text(
                    currencyFormatter.format(totalPrice),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCheckingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 