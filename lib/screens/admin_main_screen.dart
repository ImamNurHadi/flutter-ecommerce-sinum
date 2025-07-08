import 'package:flutter/material.dart';
import 'package:sinum/models/product_model.dart';
import 'package:sinum/widgets/product_card.dart';
import 'package:sinum/screens/search_screen.dart';
import 'package:sinum/screens/profile_screen.dart';
import 'package:sinum/screens/product_management_screen.dart';
import 'package:sinum/services/firebase_service.dart';
import 'package:sinum/services/auth_service.dart';
import 'package:sinum/models/user_model.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Widget> get _screens {
    return [
      const AdminHomeScreen(),
      const SearchScreen(),
      const ProductManagementScreen(),
      const ProfileScreen(),
    ];
  }

  List<BottomNavigationBarItem> get _navItems {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Search',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'Products',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF6B35),
        unselectedItemColor: Colors.grey,
        items: _navItems,
      ),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int selectedCategoryIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  
  // Data loading state
  bool isLoading = true;
  List<Product> allProducts = [];

  @override
  void initState() {
    super.initState();
    // Load products from Firebase
    loadProducts();
  }

  void loadProducts() async {
    try {
      final products = await _firebaseService.getProductsOnce();
      setState(() {
        allProducts = products;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() {
        isLoading = false;
        // Fallback to hardcoded data jika Firebase gagal
        allProducts = _getFallbackProducts();
      });
    }
  }

  // Fallback data jika Firebase tidak tersedia
  List<Product> _getFallbackProducts() => const [
    // Produk Cookies
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
    // Produk Martabak
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

  final List<String> categories = const [
    'Popular',
    'Cookies',
    'Martabak',
    'Terangbulan',
  ];

  // Filter produk berdasarkan kategori yang dipilih
  List<Product> get filteredProducts {
    if (selectedCategoryIndex == 0) {
      // Popular - tampilkan semua produk
      return allProducts;
    } else {
      // Filter berdasarkan kategori yang dipilih
      String selectedCategory = categories[selectedCategoryIndex];
      return allProducts.where((product) => product.category == selectedCategory).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFFFF8A65),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome text
                    const Text(
                      'Selamat datang, Admin!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kelola produk dan monitor toko Anda',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Actions Section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            'Tambah Produk',
                            Icons.add_circle,
                            Colors.green,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProductManagementScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            'Kelola Stok',
                            Icons.inventory,
                            Colors.blue,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProductManagementScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            'Kelola Transaksi',
                            Icons.receipt_long,
                            Colors.orange,
                            () {
                              Navigator.pushNamed(context, '/admin-transactions');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            'Laporan',
                            Icons.analytics,
                            Colors.purple,
                            () {
                              // TODO: Implementasi laporan
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fitur laporan akan segera hadir'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Category Selection
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategori Produk',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Chips
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final isSelected = index == selectedCategoryIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryIndex = index;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFF6B35) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFF6B35) : Colors.grey.withOpacity(0.3),
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: Text(
                                  categories[index],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Products Grid
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produk ${categories[selectedCategoryIndex]}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Loading state
                    if (isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                        ),
                      )
                    else if (filteredProducts.isEmpty)
                      const Center(
                        child: Text(
                          'Belum ada produk dalam kategori ini',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      // Products Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          return AdminProductCard(product: filteredProducts[index]);
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminProductCard extends StatelessWidget {
  final Product product;

  const AdminProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
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
                // Navigate to product management instead of detail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductManagementScreen(),
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
                      child: ProductCard.buildProductImage(product),
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
                  // Admin Badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
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
                  'Rp ${product.price.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(height: 6),
                // Manage Button
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProductManagementScreen(),
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
                      'Kelola',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 