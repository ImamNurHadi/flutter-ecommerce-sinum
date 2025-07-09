import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sinum/models/product_model.dart';
import 'package:sinum/widgets/product_card.dart';
import 'package:sinum/screens/search_screen.dart';
import 'package:sinum/screens/cart_screen.dart';
import 'package:sinum/screens/profile_screen.dart';
import 'package:sinum/screens/auth_wrapper.dart';
import 'package:sinum/screens/login_screen.dart';
import 'package:sinum/screens/register_screen.dart';
import 'package:sinum/screens/admin_dashboard.dart';
import 'package:sinum/screens/admin_main_screen.dart';
import 'package:sinum/screens/transaction_screen.dart';
import 'package:sinum/screens/debug_transaction_screen.dart';
import 'package:sinum/screens/admin_transaction_management_screen.dart';
import 'package:sinum/services/firebase_service.dart';
import 'package:sinum/services/auth_service.dart';
import 'package:sinum/services/cart_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SinumApp());
}

// Global app refresh mechanism
class GlobalAppRefresh {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static ValueNotifier<int> refreshNotifier = ValueNotifier(0);
  
  static void forceRefreshApp() {
    debugPrint('🔄 GlobalAppRefresh: Force refresh app called');
    refreshNotifier.value++;
    
    // Also try to navigate to fresh AuthWrapper
    final context = navigatorKey.currentContext;
    if (context != null) {
      debugPrint('🔄 GlobalAppRefresh: Navigating to fresh AuthWrapper');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth-wrapper', 
        (route) => false,
      );
    }
  }
}

class SinumApp extends StatelessWidget {
  const SinumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GlobalAppRefresh.refreshNotifier,
      builder: (context, refreshCount, child) {
        debugPrint('🔄 SinumApp: Rebuilding app (refresh count: $refreshCount)');
        
        return MaterialApp(
          title: 'Sinum - Food Delivery',
          navigatorKey: GlobalAppRefresh.navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF6B35), // Orange untuk food app
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          home: AuthWrapper(key: ValueKey('auth_wrapper_$refreshCount')),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/main': (context) => AuthWrapper(key: ValueKey('main_auth_wrapper_${DateTime.now().millisecondsSinceEpoch}')),
            '/auth-wrapper': (context) => AuthWrapper(key: ValueKey('fresh_auth_wrapper_${DateTime.now().millisecondsSinceEpoch}')),
            '/admin': (context) => const AdminDashboard(),
            '/admin-main': (context) => const AdminMainScreen(),
            '/transactions': (context) => const TransactionScreen(),
            '/debug-transaction': (context) => const DebugTransactionScreen(),
            '/admin-transactions': (context) => const AdminTransactionManagementScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
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
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  bool _isLoading = true;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart count when returning to app
    _updateCartCount();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        final cartCount = await _cartService.getCartItemCount(userData.uid);
        setState(() {
          _cartItemCount = cartCount;
        });
      }
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

  Future<void> _updateCartCount() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null) {
        final cartCount = await _cartService.getCartItemCount(userData.uid);
        setState(() {
          _cartItemCount = cartCount;
        });
      }
    } catch (e) {
      debugPrint('Error updating cart count: $e');
    }
  }

  List<Widget> get _screens {
    return [
      const HomeScreen(),
      const SearchScreen(),
      const CartScreen(),
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
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            const Icon(Icons.shopping_cart),
            if (_cartItemCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_cartItemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: 'Cart',
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
          // Update cart count when navigating to or from cart screen
          _updateCartCount();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF6B35),
        unselectedItemColor: Colors.grey,
        items: _navItems,
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
                                    color: Colors.white.withValues(alpha: 0.9),
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
                            color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.9),
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
                                    : Colors.grey.withValues(alpha: 0.3),
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
                    const SizedBox(height: 16),
                    // Loading state
                    if (isLoading)
                      SizedBox(
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
                                    ? 'Belum ada produk tersedia'
                                    : 'Coba kategori lain',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
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
