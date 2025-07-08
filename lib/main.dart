import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sinum/models/product_model.dart';
import 'package:sinum/widgets/product_card.dart';
import 'package:sinum/screens/search_screen.dart';
import 'package:sinum/screens/cart_screen.dart';
import 'package:sinum/screens/profile_screen.dart';
import 'package:sinum/screens/add_product_screen.dart';
import 'package:sinum/screens/product_management_screen.dart';
import 'package:sinum/screens/auth_wrapper.dart';
import 'package:sinum/screens/login_screen.dart';
import 'package:sinum/screens/register_screen.dart';
import 'package:sinum/screens/admin_dashboard.dart';
import 'package:sinum/services/firebase_service.dart';
import 'package:sinum/test_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SinumApp());
}

class SinumApp extends StatelessWidget {
  const SinumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinum - Food Delivery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35), // Orange untuk food app
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/admin': (context) => const AdminDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const ProductManagementScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      print('Error loading products: $e');
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to Add Product Screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProductScreen(),
            ),
          );
          
          // Refresh products if new product was added
          if (result == true) {
            loadProducts();
          }
        },
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hello, Foodies!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Jakarta, Indonesia',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sinum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Delicious food delivered to your door',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryIndex = index;
                              });
                            },
                            child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                                color: index == selectedCategoryIndex
                                  ? const Color(0xFFFF6B35)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                  color: index == selectedCategoryIndex
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              categories[index],
                              style: TextStyle(
                                  color: index == selectedCategoryIndex ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
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

              // Featured Products
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedCategoryIndex == 0 
                              ? 'Featured Items' 
                              : '${categories[selectedCategoryIndex]} Items',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AddProductScreen(),
                                  ),
                                );
                                if (result == true) {
                                  loadProducts();
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B35),
                                backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Tambah',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Loading state
                    if (isLoading)
                      Container(
                        height: 200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFFF6B35),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading products from Firebase...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    // No products state
                    else if (filteredProducts.isEmpty)
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allProducts.isEmpty ? Icons.add_shopping_cart : Icons.fastfood_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                allProducts.isEmpty 
                                    ? 'Belum ada produk'
                                    : 'Tidak ada produk di kategori ini',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allProducts.isEmpty 
                                    ? 'Tap tombol + untuk menambahkan produk pertama'
                                    : 'Coba kategori lain atau tambahkan produk baru',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (allProducts.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AddProductScreen(),
                                      ),
                                    );
                                    if (result == true) {
                                      loadProducts();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B35),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Produk'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    // Products grid
                    else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                        itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                          return ProductCard(product: filteredProducts[index]);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
