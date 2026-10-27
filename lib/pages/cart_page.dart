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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Sepetiniz boş',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Market bölümünden ürün ekleyebilirsiniz.',
            style: TextStyle(color: Colors.grey),
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
          color: Colors.white,
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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