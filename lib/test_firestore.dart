import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestFirestoreScreen extends StatefulWidget {
  const TestFirestoreScreen({super.key});

  @override
  State<TestFirestoreScreen> createState() => _TestFirestoreScreenState();
}

class _TestFirestoreScreenState extends State<TestFirestoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _status = 'Siap untuk test';
  bool _isLoading = false;

  Future<void> _checkCollections() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking collections...';
    });

    try {
      // Check products collection
      final productsSnapshot = await _firestore.collection('products').limit(5).get();
      final testSnapshot = await _firestore.collection('test').limit(5).get();

      setState(() {
        _status = '''✅ Collections found:
- products: ${productsSnapshot.docs.length} documents
- test: ${testSnapshot.docs.length} documents

Total collections checked: 2''';
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error checking collections: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFirestore() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Firestore...';
    });

    try {
      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ User tidak terautentikasi';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _status = '✅ User terautentikasi: ${user.uid}';
      });

      // Test write to Firestore
      await _firestore.collection('test').add({
        'message': 'Hello Firestore!',
        'timestamp': FieldValue.serverTimestamp(),
        'user': user.uid,
      });

      setState(() {
        _status = '✅ Firestore write berhasil!';
      });

      // Test read from Firestore
      final snapshot = await _firestore.collection('test').limit(1).get();
      
      setState(() {
        _status = '✅ Firestore read berhasil! Docs: ${snapshot.docs.length}';
      });

      // Test product collection
      final productRef = await _firestore.collection('products').add({
        'name': 'Test Product',
        'description': 'Test description',
        'price': 15000,
        'imageUrl': '',
        'category': 'Test',
        'isChilled': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = '✅ Product collection dibuat dengan ID: ${productRef.id}';
      });

      // Verify the product was created
      final productDoc = await productRef.get();
      if (productDoc.exists) {
        setState(() {
          _status = '✅ Semua test berhasil! Products collection dibuat dengan ID: ${productRef.id}';
        });
      } else {
        setState(() {
          _status = '❌ Product document tidak ditemukan setelah dibuat';
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Firestore'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testFirestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Testing...'),
                      ],
                    )
                  : const Text(
                      'Test Firestore Connection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkCollections,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Check Collections',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 