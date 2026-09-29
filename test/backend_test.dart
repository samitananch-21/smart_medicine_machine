import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_medicine_machine/data/medicine_data.dart';
import 'package:smart_medicine_machine/models/medicine.dart';
import 'package:smart_medicine_machine/screens/checkout_page.dart';
import 'package:smart_medicine_machine/services/backend_client.dart';
import 'package:smart_medicine_machine/state/cart.dart';
import 'package:smart_medicine_machine/state/catalog.dart';

http.Response jsonResponse(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Medicine product({double price = 25, int stock = 2, bool active = true}) =>
    Medicine(
        id: 'p001',
        name: 'Test product',
        detail: 'Details',
        price: price,
        image: 'assets/images/para.png',
        stock: stock,
        active: active);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
      'Cart merges stable product IDs, enforces stock, and reconciles admin changes',
      () {
    final basket = Cart();
    addTearDown(basket.dispose);
    final original = product(stock: 3);
    expect(basket.add(original), isTrue);
    expect(basket.add(product(stock: 3)), isTrue);
    expect(basket.lines.length, 1);
    expect(basket.count, 2);
    final checkoutSnapshot = basket.order;
    basket.reconcile([product(price: 30, stock: 1)]);
    expect(basket.count, 1);
    expect(basket.order.total, 3000);
    expect(checkoutSnapshot.total, 5000);
    expect(basket.add(original), isFalse);
    basket.reconcile([product(active: false)]);
    expect(basket.count, 0);
    expect(basket.add(original), isFalse);
  });

  test(
      'API uses bearer authorization only for admin and clears expired session',
      () async {
    final requests = <http.Request>[];
    final client = BackendClient(client: MockClient((request) async {
      requests.add(request);
      switch (request.url.path) {
        case '/api/admin/login':
          return jsonResponse({'token': 'test-token', 'username': 'admin'});
        case '/api/products':
          return jsonResponse({
            'products': [product().toJson()]
          });
        default:
          return jsonResponse({'error': 'เซสชันหมดอายุ'}, 401);
      }
    }));
    addTearDown(client.close);
    await client.login(' admin ', 'test-password');
    expect(client.isLoggedIn, isTrue);
    final loaded = await client.fetchProducts();
    expect(loaded.single.priceSatang, 2500);
    expect(requests.last.headers['authorization'], isNull);
    await expectLater(
        client.fetchOrders(),
        throwsA(
            isA<BackendException>().having((e) => e.status, 'status', 401)));
    expect(requests.last.headers['authorization'], 'Bearer test-token');
    expect(client.isLoggedIn, isFalse);
    final count = requests.length;
    await expectLater(client.fetchOrders(), throwsA(isA<BackendException>()));
    expect(requests.length, count);
  });

  group('Checkout API', () {
    late BackendClient previousBackend;
    late List<Medicine> previousMedicines;
    late bool previousLoaded;
    late String? previousError;
    setUp(() {
      previousBackend = backend;
      previousMedicines = medicines;
      previousLoaded = catalog.loaded;
      previousError = catalog.error;
      cart.clear();
      cart.reconcile([product()]);
      cart.add(product());
    });
    tearDown(() {
      backend.close();
      backend = previousBackend;
      medicines = previousMedicines;
      cart.clear();
      cart.reconcile(previousMedicines);
      catalog.loaded = previousLoaded;
      catalog.error = previousError;
    });

    Future<void> openCheckout(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => CheckoutPage(
                                  order: cart.order, initialMethod: 'qr'))),
                      child: const Text('Open checkout'))))));
      await tapVisible(tester, find.text('Open checkout'));
    }

    testWidgets(
        'Network failure retains cart and request ID; retry saves only once',
        (tester) async {
      final responses = Completer<http.Response>();
      final payloads = <Map<String, dynamic>>[];
      backend = BackendClient(client: MockClient((request) async {
        if (request.url.path == '/api/products') {
          return jsonResponse({
            'products': [product(stock: 1).toJson()]
          });
        }
        payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (payloads.length == 1) return responses.future;
        return jsonResponse({
          'order': {'id': 'order-test', 'status': 'pending'}
        });
      }))
        ..enabled = true;
      await openCheckout(tester);
      final confirm =
          find.widgetWithText(FilledButton, 'ยืนยันการชำระเงินทดลอง');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      expect(find.text('กำลังบันทึกคำสั่งซื้อ…'), findsOneWidget);
      expect(cart.count, 1);
      expect(payloads.length, 1);
      await tester.pageBack();
      await tester.pump();
      expect(find.byType(CheckoutPage), findsOneWidget);
      responses.completeError(http.ClientException('response lost'));
      await tester.pumpAndSettle();
      expect(cart.count, 1);
      expect(find.text('ทำรายการทดลองสำเร็จ'), findsNothing);
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'เงินสด'))
              .onSelected,
          isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      await tapVisible(tester, confirm);
      expect(payloads.length, 2);
      expect(payloads[1], payloads[0]);
      expect(payloads.first['items'], [
        {'product_id': 'p001', 'quantity': 1, 'unit_price_satang': 2500}
      ]);
      expect(find.text('ทำรายการทดลองสำเร็จ'), findsOneWidget);
      expect(find.textContaining('order-test'), findsOneWidget);
      expect(cart.count, 0);
      expect(tester.takeException(), isNull);
    });

    for (final cancelled in [false, true]) {
      testWidgets(
          'Rejected or cancelled order keeps cart (cancelled: $cancelled)',
          (tester) async {
        backend = BackendClient(client: MockClient((request) async {
          if (request.url.path == '/api/products') {
            return jsonResponse({
              'products': [product(price: 30).toJson()]
            });
          }
          return cancelled
              ? jsonResponse({
                  'order': {'id': 'cancelled-id', 'status': 'cancelled'}
                })
              : jsonResponse({'error': 'ราคาสินค้าเปลี่ยนแล้ว'}, 409);
        }))
          ..enabled = true;
        await openCheckout(tester);
        await tapVisible(tester, find.text('ยืนยันการชำระเงินทดลอง'));
        expect(cart.count, 1);
        expect(find.text('ทำรายการทดลองสำเร็จ'), findsNothing);
        expect(
            tester
                .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'ยืนยันการชำระเงินทดลอง'))
                .onPressed,
            isNull);
        await tapVisible(tester, find.text('กลับไปตรวจตะกร้าและราคาล่าสุด'));
        expect(find.byType(CheckoutPage), findsNothing);
        expect(cart.order.total, 3000);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
