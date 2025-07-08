import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart' as app;
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class AdminTransactionManagementScreen extends StatefulWidget {
  const AdminTransactionManagementScreen({super.key});

  @override
  State<AdminTransactionManagementScreen> createState() => _AdminTransactionManagementScreenState();
}

class _AdminTransactionManagementScreenState extends State<AdminTransactionManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  List<app.Transaction> _transactions = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  
  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      // Get all transactions for admin view
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();
      
      final transactions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app.Transaction.fromFirestore(data, doc.id);
      }).toList();

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🚨 Error loading transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTransactionStatus(String transactionId, app.TransactionStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .update({
        'status': newStatus.value,
        'updatedAt': Timestamp.now(),
      });

      // Refresh the list
      await _loadTransactions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status transaksi berhasil diubah ke ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('🚨 Error updating transaction status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengubah status transaksi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<app.Transaction> get _filteredTransactions {
    if (_filterStatus == 'all') return _transactions;
    
    final filterStatusEnum = app.TransactionStatus.fromString(_filterStatus);
    return _transactions.where((t) => t.status == filterStatusEnum).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Transaksi'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadTransactions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Status
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('all', 'Semua'),
                    _buildFilterChip('pending', 'Pending'),
                    _buildFilterChip('processing', 'Diproses'),
                    _buildFilterChip('shipped', 'Dikirim'),
                    _buildFilterChip('delivered', 'Selesai'),
                    _buildFilterChip('cancelled', 'Dibatalkan'),
                  ],
                ),
              ],
            ),
          ),
          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filterStatus == 'all' 
                                  ? 'Belum ada transaksi'
                                  : 'Tidak ada transaksi dengan status ini',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _filteredTransactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange,
    );
  }

  Widget _buildTransactionCard(app.Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(transaction.status),
          child: Text(
            transaction.totalItems.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          transaction.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${_formatCurrency(transaction.totalAmount)}'),
            Text(
              'Status: ${transaction.status.displayName}',
              style: TextStyle(
                color: _getStatusColor(transaction.status),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction Details
                _buildDetailRow('ID Transaksi', transaction.id ?? '-'),
                _buildDetailRow('Email', transaction.userEmail),
                if (transaction.phoneNumber != null)
                  _buildDetailRow('Telepon', transaction.phoneNumber!),
                if (transaction.deliveryAddress != null)
                  _buildDetailRow('Alamat', transaction.deliveryAddress!),
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  _buildDetailRow('Catatan', transaction.notes!),
                
                const SizedBox(height: 16),
                
                // Items
                const Text(
                  'Item Pesanan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...transaction.items.map((item) => _buildItemRow(item)),
                
                const SizedBox(height: 16),
                
                // Status Management
                const Text(
                  'Ubah Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: app.TransactionStatus.values.map((status) {
                    final isCurrentStatus = transaction.status == status;
                    return ElevatedButton(
                      onPressed: isCurrentStatus 
                          ? null 
                          : () => _updateTransactionStatus(transaction.id!, status),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrentStatus 
                            ? Colors.grey 
                            : _getStatusColor(status),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        status.displayName,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(app.TransactionItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.productImageUrl.startsWith('http')
                ? Image.network(
                    item.productImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  )
                : Image.asset(
                    item.productImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item.quantity}x ${_formatCurrency(item.price)} = ${_formatCurrency(item.subtotal)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(app.TransactionStatus status) {
    switch (status) {
      case app.TransactionStatus.pending:
        return Colors.orange;
      case app.TransactionStatus.processing:
        return Colors.blue;
      case app.TransactionStatus.shipped:
        return Colors.purple;
      case app.TransactionStatus.delivered:
        return Colors.green;
      case app.TransactionStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
} 