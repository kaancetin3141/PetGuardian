import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petguardian/pages/cart_page.dart';
import 'package:petguardian/pages/shop_page.dart';

const String me = 'uid_me';

ProductInfo product(String title, double price) =>
    ProductInfo('images/shop_images/product1.jpg', title, price);

Future<void> pumpCart(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  List<ProductInfo> items,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CartPage(
        productList: items,
        firestore: firestore,
        userUID: me,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('CartPage', () {
    testWidgets('shows the items and the total', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await pumpCart(tester, firestore, [product('Tasma', 99.99), product('Mama', 50.00)]);

      expect(find.text('Tasma'), findsOneWidget);
      expect(find.text('Mama'), findsOneWidget);
      expect(find.text('₺149,99'), findsOneWidget);
    });

    testWidgets('quantity controls change the total', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await pumpCart(tester, firestore, [product('Tasma', 99.99)]);

      expect(find.text('₺99,99'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('₺199,98'), findsOneWidget);
    });

    testWidgets('shows an empty state when the cart is empty', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await pumpCart(tester, firestore, <ProductInfo>[]);

      expect(find.text('Sepetiniz boş'), findsOneWidget);
      expect(find.text('Siparişi Onayla'), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps the cart and writes nothing',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final items = [product('Tasma', 99.99)];
      await pumpCart(tester, firestore, items);

      await tester.tap(find.text('Siparişi Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(items, hasLength(1));
      final orders = await firestore.collection('orders').get();
      expect(orders.docs, isEmpty);
    });

    testWidgets('confirming writes an order and clears the cart', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final items = [product('Tasma', 99.99), product('Mama', 50.00)];
      await pumpCart(tester, firestore, items);

      await tester.tap(find.text('Siparişi Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();

      final orders = await firestore.collection('orders').get();
      expect(orders.docs, hasLength(1));

      final order = orders.docs.first.data();
      expect(order['userUID'], me);
      expect(order['totalCents'], 14999);
      expect(order['status'], 'pending_payment');
      expect(order['currency'], 'TRY');
      expect((order['items'] as List), hasLength(2));
      expect(items, isEmpty);

      // Confirmation is surfaced to the user.
      expect(find.textContaining('Siparişiniz oluşturuldu'), findsOneWidget);
    });

    testWidgets('quantities are stored per line item', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await pumpCart(tester, firestore, [product('Tasma', 99.99)]);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siparişi Onayla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();

      final orders = await firestore.collection('orders').get();
      final items = (orders.docs.first.data()['items'] as List).cast<Map>();
      expect(items.single['quantity'], 2);
      expect(items.single['unitPriceCents'], 9999);
    });
  });
}