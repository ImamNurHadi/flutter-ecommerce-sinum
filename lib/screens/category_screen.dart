import 'package:flutter/material.dart';
import 'package:sinum/models/product_model.dart';
import 'package:sinum/widgets/product_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Breakfast',
    'Desserts',
    'Snacks',
    'Beverages',
    'Special',
  ];

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

  List<Product> get filteredProducts {
    if (selectedCategory == 'All') {
      return allProducts;
    }
    return allProducts.where((product) => product.category == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Categories',
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
          // Category Filter
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF6B35) : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF6B35)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Products Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
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
            ),
          ),
        ],
      ),
    );
  }
} 