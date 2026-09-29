import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_medicine_machine/data/medicine_data.dart';
import 'package:smart_medicine_machine/models/medicine.dart';
import 'package:smart_medicine_machine/screens/admin/admin_page.dart';
import 'package:smart_medicine_machine/screens/admin/product_editor.dart';
import 'package:smart_medicine_machine/services/backend_client.dart';
import 'package:smart_medicine_machine/state/cart.dart';
import 'package:smart_medicine_machine/state/catalog.dart';

class _AdminApi {
  Map<String, dynamic> product = {
    'id': 'product-1',
    'name': 'สินค้าทดสอบ',
    'detail': 'รายละเอียดสำหรับทดสอบระบบจัดการสินค้า',
    'price_satang': 2500,
    'image': 'assets/images/para.png',
    'category': 'ยาและบรรเทาอาการ',
    'warning': null,
    'stock': 8,
    'active': true,
    'version': 1,
  };
  Map<String, dynamic> order = {
    'id': 'order-1',
    'status': 'pending',
    'created_at': '2026-09-28T10:00:00Z',
    'payment_method': 'cash',
    'payment_mode': 'demo',
    'subtotal_satang': 5000,
    'discount_satang': 0,
    'total_satang': 5000,
    'paid_satang': 10000,
    'change_satang': 5000,
    'coupon': null,
    'items': [
      {
        'product_id': 'product-1',
        'name': 'สินค้าทดสอบ',
        'quantity': 2,
        'unit_price_satang': 2500,
        'total_satang': 5000,
      },
    ],
  };
  final requests = <http.Request>[];
  Completer<void>? saveGate;
  bool expireSession = false;

  http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final data = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/api/admin/login') {
      if (data['username'] != 'test-admin' || data['password'] != 'test-only') {
        return _json({'error': 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'}, 401);
      }
      return _json({'token': 'test-token', 'username': 'test-admin'});
    }
    if (path.startsWith('/api/admin/') &&
        (expireSession ||
            request.headers['authorization'] != 'Bearer test-token')) {
      return _json({'error': 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง'}, 401);
    }
    if (path == '/api/admin/logout') return _json({'ok': true});
    if (path == '/api/admin/products') {
      return _json({
        'products': [product]
      });
    }
    if (path == '/api/admin/products/product-1' && request.method == 'PUT') {
      await saveGate?.future;
      product = {
        ...product,
        ...data,
        'version': (product['version'] as int) + 1
      };
      return _json({'product': product});
    }
    if (path == '/api/products') {
      return _json({
        'products': product['active'] == true ? [product] : []
      });
    }
    if (path == '/api/admin/orders') {
      return _json({
        'orders': [order]
      });
    }
    if (path == '/api/admin/orders/order-1' && request.method == 'PATCH') {
      order = {...order, 'status': data['status']};
      if (data['status'] == 'cancelled') {
        product = {...product, 'stock': (product['stock'] as int) + 2};
      }
      return _json({'order': order});
    }
    return _json({'error': 'Unexpected test route'}, 404);
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester,
    {String password = 'test-only'}) async {
  await tester.ensureVisible(find.byKey(const Key('admin-username')));
  await tester.enterText(find.byKey(const Key('admin-username')), 'test-admin');
  await tester.ensureVisible(find.byKey(const Key('admin-password')));
  await tester.enterText(find.byKey(const Key('admin-password')), password);
  await _tap(tester, find.byKey(const Key('admin-login')));
}

void main() {
  late BackendClient previousBackend;
  late List<Medicine> previousMedicines;
  late bool previousLoaded;
  late String? previousError;
  late _AdminApi api;

  setUp(() {
    previousBackend = backend;
    previousMedicines = medicines;
    previousLoaded = catalog.loaded;
    previousError = catalog.error;
    catalog.loaded = false;
    catalog.error = null;
    cart.clear();
    api = _AdminApi();
    backend = BackendClient(
        baseUrl: 'http://test.local:8765', client: MockClient(api.handle))
      ..enabled = true;
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

  testWidgets('Admin rejects bad credentials and logs in and out with API',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPage()));
    await _login(tester, password: 'wrong');
    expect(find.text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
    expect(backend.isLoggedIn, isFalse);
    expect(find.text('ดูแลร้านของคุณ'), findsNothing);

    await _login(tester);
    expect(find.text('ดูแลร้านของคุณ'), findsOneWidget);
    expect(find.text('สินค้าทดสอบ'), findsOneWidget);
    expect(backend.isLoggedIn, isTrue);
    await _tap(tester, find.byTooltip('ออกจากระบบแอดมิน'));
    expect(find.byKey(const Key('admin-login')), findsOneWidget);
    expect(backend.isLoggedIn, isFalse);
    expect(api.requests.any((r) => r.url.path == '/api/admin/logout'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Editing product waits for save and refreshes authoritative catalog',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPage()));
    await _login(tester);
    await _tap(tester, find.byTooltip('แก้ไข สินค้าทดสอบ'));
    expect(find.byType(ProductEditor), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('admin-product-price')));
    await tester.enterText(
        find.byKey(const Key('admin-product-price')), '42.75');
    await tester.ensureVisible(find.byKey(const Key('admin-product-stock')));
    await tester.enterText(find.byKey(const Key('admin-product-stock')), '11');
    api.saveGate = Completer<void>();
    final save = find.byKey(const Key('admin-product-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(find.byType(ProductEditor), findsOneWidget);
    expect(find.text('กำลังบันทึก…'), findsOneWidget);
    expect(api.product['price_satang'], 2500);

    api.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProductEditor), findsNothing);
    expect(find.text('42.75 บาท'), findsOneWidget);
    expect(find.text('คงเหลือ 11 ชิ้น'), findsOneWidget);
    expect(medicines.single.priceSatang, 4275);
    expect(medicines.single.stock, 11);
    final request = api.requests.singleWhere((r) => r.method == 'PUT');
    final payload = jsonDecode(request.body) as Map<String, dynamic>;
    expect(payload['version'], 1);
    expect(payload['price_satang'], 4275);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelling an order requires confirmation and reloads stock',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPage()));
    await _login(tester);
    await _tap(tester, find.widgetWithText(ChoiceChip, 'คำสั่งซื้อ'));
    await _tap(tester, find.text('คำสั่งซื้อ #order-1'));
    await _tap(tester, find.text('ยกเลิกและคืนสต็อก'));
    expect(find.text('ยกเลิกคำสั่งซื้อนี้?'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    await _tap(tester, find.text('กลับ'));
    expect(api.order['status'], 'pending');

    await _tap(tester, find.text('ยกเลิกและคืนสต็อก'));
    await _tap(tester, find.text('ยืนยันยกเลิกคำสั่งซื้อ'));
    expect(api.order['status'], 'cancelled');
    expect(find.text('ยกเลิกและคืนสต็อก'), findsNothing);
    expect(medicines.single.stock, 10);
    expect(api.requests.where((r) => r.method == 'PATCH').length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expired admin session returns to login with a useful error',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPage()));
    await _login(tester);
    api.expireSession = true;
    await _tap(tester, find.byTooltip('รีเฟรชข้อมูล'));
    expect(backend.isLoggedIn, isFalse);
    expect(find.byKey(const Key('admin-login')), findsOneWidget);
    expect(find.text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Admin login, catalog and product editor fit narrow large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
        child: child!,
      ),
      home: const AdminPage(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _login(tester);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('แก้ไข สินค้าทดสอบ'));
    expect(find.byType(ProductEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('admin-product-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('ยกเลิก'));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'คำสั่งซื้อ'));
    await _tap(tester, find.text('คำสั่งซื้อ #order-1'));
    expect(tester.takeException(), isNull);
  });
}
