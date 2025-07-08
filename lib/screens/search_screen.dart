import 'package:flutter/material.dart';
import 'package:sinum/models/product_model.dart';
import 'package:sinum/widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> searchResults = [];
  bool isLoading = false;

  final List<Product> allProducts = const [
    Product(
      name: 'Chocolate Peanut Butter Bowl',
      description: 'Rich chocolate bowl with creamy peanut butter and brownie chunks',
      price: 18.99,
      imageUrl: 'assets/images/cookies/964fefc4-77ce-4f56-bde6-064d181822d4_ChocolatePeanutButterBrownie_LTO_FlyingAerial_TECH.png',
      category: 'Desserts',
    ),
    Product(
      name: 'French Toast Delight',
      description: 'Classic French toast with maple syrup and cinnamon butter',
      price: 12.99,
      imageUrl: 'assets/images/cookies/46bf1e33-f9bf-40ce-be5e-f02de5d47146_FrenchToast_FlyingAerial_TECH.png',
      category: 'Breakfast',
    ),
    Product(
      name: 'Dirt Cake Parfait',
      description: 'Chocolate cake parfait with crushed cookies and gummy treats',
      price: 14.99,
      imageUrl: 'assets/images/cookies/9c9e2619-037a-47f1-9b64-cb83307d7769_DirtCake_FlyingAerial_TECH.png',
      category: 'Desserts',
    ),
    Product(
      name: 'Raspberry Lemonade Cake',
      description: 'Refreshing lemon cake with fresh raspberry topping',
      price: 16.99,
      imageUrl: 'assets/images/cookies/8e31c971-09e9-4e08-b1d6-765ed1f9f0dc_RaspberryLemonade_FlyingAerial_TECH.png',
      category: 'Desserts',
    ),
    Product(
      name: 'S\'mores Special',
      description: 'Campfire-style s\'mores with marshmallow and chocolate',
      price: 15.99,
      imageUrl: 'assets/images/cookies/ce1deb6c-c43d-434f-890a-d5d12d4de95b_Smores_FlyingAerial_TECH.png',
      category: 'Snacks',
    ),
    Product(
      name: 'Churro Cake Supreme',
      description: 'Cinnamon sugar churro cake with dulce de leche drizzle',
      price: 13.99,
      imageUrl: 'assets/images/cookies/3f58c3b5-d52d-4ab1-905d-46f5012650d0_ChurroCakeDessert_FlyingAerial_TECH.png',
      category: 'Special',
    ),
    Product(
      name: 'Milk Chocolate Chip Treat',
      description: 'Classic chocolate chip dessert with premium milk chocolate',
      price: 11.99,
      imageUrl: 'assets/images/cookies/6c54f810-416b-4266-a628-fc00b5d4ed49_MilkChocolateChip_FlyingAerial_TECH.png',
      category: 'Desserts',
    ),
  ];

  final List<String> popularSearches = [
    'Chocolate',
    'French Toast',
    'Desserts',
    'S\'mores',
    'Cake',
    'Sweet Treats',
  ];

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        searchResults = allProducts
            .where((product) =>
                product.name.toLowerCase().contains(query.toLowerCase()) ||
                product.description.toLowerCase().contains(query.toLowerCase()) ||
                product.category.toLowerCase().contains(query.toLowerCase()))
            .toList();
        isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D2D2D),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(20),
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
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: const InputDecoration(
                hintText: 'Search for food...',
                prefixIcon: Icon(Icons.search, color: Color(0xFFFF6B35)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          // Search Results or Popular Searches
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildPopularSearches()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularSearches() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: popularSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    search,
                    style: const TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B35),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${searchResults.length} results found',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return ProductCard(product: searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
} 