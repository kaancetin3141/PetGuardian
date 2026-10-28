import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import './shop_page.dart';

class CartPage extends StatefulWidget {
  final List<ProductInfo> productList;

  /// Injectable for tests; defaults to the ambient Firestore instance.
  final FirebaseFirestore? firestore;

  /// Injectable for tests; defaults to the signed-in user.
  final String? userUID;

  const CartPage({
    super.key,
    required this.productList,
    this.firestore,
    this.userUID,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<int> productQuantities = [];
  bool _isPlacingOrder = false;

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  String? get _uid => widget.userUID ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Varsayılan ürün miktarlarını ayarla
    for (int i = 0; i < widget.productList.length; i++) {
      productQuantities.add(1);
    }
  }

  void _incrementQuantity(int index) {
    setState(() {
      productQuantities[index]++;
    });
  }

  void _decrementQuantity(int index) {
    if (productQuantities[index] > 1) {
      setState(() {
        productQuantities[index]--;
      });
    } else {
      _removeProduct(index);
    }
  }

  void _removeProduct(int index) {
    setState(() {
      widget.productList.removeAt(index);
      productQuantities.removeAt(index);
    });
  }

  /// Total in minor units (kuruş). Money is never accumulated as a double.
  int get _totalCents {
    var total = 0;
    for (int i = 0; i < widget.productList.length; i++) {
      total += (widget.productList[i].price * 100).round() * productQuantities[i];
    }
    return total;
  }

  String get _formattedTotal =>
      '${(_totalCents / 100).toStringAsFixed(2)} TL';

  Future<void> _buyProducts() async {
    if (widget.productList.isEmpty || _isPlacingOrder) return;

    final uid = _uid;
    if (uid == null) {
      _showMessage('Sipariş vermek için giriş yapmalısınız.', isError: true);
      return;
    }

    // Confirms the order before anything is written.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Siparişi Onayla'),
        content: Text(
          '${widget.productList.length} ürün için $_formattedTotal tutarındaki '
          'sipariş oluşturulacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isPlacingOrder = true);

    final orderRef = _db.collection('orders').doc();
    try {
      await orderRef.set({
        'userUID': uid,
        'items': <Map<String, dynamic>>[
          for (int i = 0; i < widget.productList.length; i++)
            {
              'title': widget.productList[i].title,
              'imagePath': widget.productList[i].imagePath,
              'unitPriceCents': (widget.productList[i].price * 100).round(),
              'quantity': productQuantities[i],
            },
        ],
        'totalCents': _totalCents,
        'currency': 'TRY',
        // No payment provider is wired up yet; the order waits for fulfilment.
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        widget.productList.clear();
        productQuantities.clear();
      });
      _showMessage(
        'Siparişiniz oluşturuldu.\nSipariş No: ${orderRef.id.substring(0, 8).toUpperCase()}',
      );
    } catch (e) {
      // The cart is deliberately left intact so nothing is lost on failure.
      if (!mounted) return;
      _showMessage('Sipariş oluşturulamadı: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  /// Read-only order history for the signed-in customer. The query filters on
  /// userUID only (a composite index would be required for ordering on the
  /// server side); the newest-first ordering happens client-side.
  void _openOrdersSheet() {
    final uid = _uid;
    if (uid == null) {
      _showMessage('Siparişleriniz için giriş yapmalısınız.', isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: SizedBox(
            height: 480,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Siparişlerim',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('orders')
                        .where('userUID', isEqualTo: uid)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Siparişler yüklenemedi.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? const [];
                      // Newest first on the client; createdAt is a server
                      // timestamp and may still be pending on recent orders.
                      final orders = docs.toList()
                        ..sort((a, b) {
                          final at = (a.data()['createdAt'] as Timestamp?)
                                  ?.toDate() ??
                              DateTime(2000);
                          final bt = (b.data()['createdAt'] as Timestamp?)
                                  ?.toDate() ??
                              DateTime(2000);
                          return bt.compareTo(at);
                        });

                      if (orders.isEmpty) {
                        return Center(
                          child: Text(
                            'Henüz siparişiniz yok.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, i) {
                          final data = orders[i].data();
                          final items = List<Map<String, dynamic>>.from(
                              data['items'] ?? const []);
                          final totalCents = data['totalCents'];
                          final created =
                              (data['createdAt'] as Timestamp?)?.toDate();
                          return _buildOrderCard(
                            sheetContext,
                            items: items,
                            totalCents: totalCents is int ? totalCents : 0,
                            status: data['status']?.toString() ?? '',
                            created: created,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext sheetContext, {
    required List<Map<String, dynamic>> items,
    required int totalCents,
    required String status,
    required DateTime? created,
  }) {
    final scheme = Theme.of(sheetContext).colorScheme;
    final (Color chipBg, Color chipFg, String statusLabel) = switch (status) {
      'paid' => (scheme.primaryContainer, scheme.onPrimaryContainer, 'Ödendi'),
      'shipped' => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          'Kargoya Verildi'
        ),
      'delivered' => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          'Teslim Edildi'
        ),
      'cancelled' => (scheme.errorContainer, scheme.onErrorContainer, 'İptal Edildi'),
      _ => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          'Ödeme Bekliyor'
        ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    created == null
                        ? 'Sipariş'
                        : DateFormat('dd.MM.yyyy HH:mm').format(created),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, color: chipFg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${item['quantity']}× ${item['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 16),
            Row(
              children: [
                Text(
                  'Toplam',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '₺${(totalCents / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Sepet', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Geri Dön butonunu iptal eder
        actions: [
          IconButton(
            tooltip: 'Siparişlerim',
            icon: const Icon(Icons.receipt_long),
            onPressed: _openOrdersSheet,
          ),
        ],
      ),
      body: widget.productList.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.productList.length,
                    itemBuilder: (context, index) {
                      final product = widget.productList[index];
                      final quantity = productQuantities[index];
                      return ListTile(
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: AssetImage(product.imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(product.title),
                        subtitle:
                            Text('${currency.format(product.price)} x $quantity'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _decrementQuantity(index),
                            ),
                            Text('$quantity'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _incrementQuantity(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildSummary(currency),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text(
            'Sepetiniz boş',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Market bölümünden ürün ekleyebilirsiniz.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(NumberFormat currency) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Toplam',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  currency.format(_totalCents / 100),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _buyProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isPlacingOrder
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Siparişi Onayla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}