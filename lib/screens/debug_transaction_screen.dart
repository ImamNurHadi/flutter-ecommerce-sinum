import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart' as app;
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class DebugTransactionScreen extends StatefulWidget {
  const DebugTransactionScreen({super.key});

  @override
  State<DebugTransactionScreen> createState() => _DebugTransactionScreenState();
}

class _DebugTransactionScreenState extends State<DebugTransactionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  List<app.Transaction> _transactions = [];
  List<Map<String, dynamic>> _rawTransactions = [];
  bool _isLoading = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userData = await _authService.getCurrentUserData();
      setState(() {
        _currentUser = userData;
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _checkTransactionCollection() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Memeriksa koleksi transactions...';
    });

    try {
      // Check if transactions collection exists
      final allTransactions = await _firestore.collection('transactions').get();
      
      // Check user-specific transactions
      final userTransactions = _currentUser != null 
          ? await _firestore.collection('transactions')
              .where('userId', isEqualTo: _currentUser!.uid)
              .get()
          : null;

      // Get raw data
      final rawData = allTransactions.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Parse transactions using FirebaseService
      final parsedTransactions = _currentUser != null
          ? await _firebaseService.getUserTransactions(_currentUser!.uid)
          : <app.Transaction>[];

      setState(() {
        _rawTransactions = rawData;
        _transactions = parsedTransactions;
        _debugInfo = '''
🔍 HASIL DEBUG TRANSAKSI:

📊 STATISTIK KOLEKSI:
- Total dokumen di 'transactions': ${allTransactions.docs.length}
- Transaksi user saat ini: ${userTransactions?.docs.length ?? 0}

👤 USER INFO:
- User ID: ${_currentUser?.uid ?? 'null'}
- Email: ${_currentUser?.email ?? 'null'}
- Name: ${_currentUser?.displayName ?? 'null'}

📋 TRANSAKSI YANG DITEMUKAN:
${_transactions.isEmpty ? 'Tidak ada transaksi ditemukan' : _transactions.map((t) => '- ${t.transactionNumber}: ${t.totalAmount} (${t.status.displayName})').join('\n')}

🗃️ DATA MENTAH FIRESTORE:
${rawData.isEmpty ? 'Tidak ada data mentah' : rawData.take(3).map((d) => '- Doc ID: ${d['id']}\n  User ID: ${d['userId']}\n  Total: ${d['totalAmount']}\n  Status: ${d['status']}\n  Created: ${d['createdAt']}').join('\n\n')}

${rawData.length > 3 ? '... dan ${rawData.length - 3} lainnya' : ''}
        ''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ ERROR: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testCreateTransaction() async {
    if (_currentUser == null) {
      setState(() {
        _debugInfo = '❌ User tidak login, tidak bisa test create transaction';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _debugInfo = 'Membuat transaksi test...';
    });

    try {
      // Create test transaction
      final testTransaction = app.Transaction(
        userId: _currentUser!.uid,
        userName: _currentUser!.displayName,
        userEmail: _currentUser!.email,
        items: [
          const app.TransactionItem(
            productId: 'test-product-1',
            productName: 'Test Product',
            productImageUrl: 'assets/images/martabak/Martabak_telur.jpeg',
            price: 15000,
            quantity: 2,
            subtotal: 30000,
          ),
        ],
        totalAmount: 30000,
        deliveryAddress: 'Test Address',
        phoneNumber: '081234567890',
        notes: 'Test transaction for debugging',
        createdAt: DateTime.now(),
      );

      final transactionId = await _firebaseService.createTransaction(testTransaction);
      
      if (transactionId != null) {
        setState(() {
          _debugInfo = '''
✅ TEST TRANSACTION BERHASIL DIBUAT!

📋 DETAIL:
- Transaction ID: $transactionId
- User ID: ${_currentUser!.uid}
- Total: Rp 30.000
- Status: Pending

🔄 Refresh halaman untuk melihat transaksi baru
          ''';
        });
      } else {
        setState(() {
          _debugInfo = '❌ Gagal membuat test transaction';
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo = '❌ ERROR saat membuat test transaction: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearTestTransactions() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
      _debugInfo = 'Menghapus test transactions...';
    });

    try {
      final testTransactions = await _firestore.collection('transactions')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('notes', isEqualTo: 'Test transaction for debugging')
          .get();

      for (final doc in testTransactions.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _debugInfo = '✅ ${testTransactions.docs.length} test transactions dihapus';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ ERROR saat menghapus test transactions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Transaksi'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DEBUG TRANSAKSI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkTransactionCollection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Periksa Firestore'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testCreateTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test Buat Transaksi'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _clearTestTransactions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hapus Test Data'),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Debug info
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _debugInfo.isEmpty
                              ? 'Klik tombol di atas untuk mulai debug'
                              : _debugInfo,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 