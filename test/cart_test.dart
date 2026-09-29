import 'package:flutter/material.dart';
import 'package:smart_medicine_machine/models/medicine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medicine_machine/data/medicine_data.dart';
import 'package:smart_medicine_machine/state/cart.dart';
import 'package:smart_medicine_machine/screens/cart_page.dart';
import 'package:smart_medicine_machine/screens/checkout_page.dart';
import 'package:smart_medicine_machine/screens/home_page.dart';
import 'package:smart_medicine_machine/main.dart';

void main() {
  setUp(cart.clear);
  tearDown(cart.clear);

  test('Quantities, coupon and immutable checkout totals', () {
    final basket = Cart();
    final first = Medicine(name: 'Test A', detail: '', price: 25, image: '');
    final second = Medicine(name: 'Test B', detail: '', price: 35, image: '');
    basket.add(first);
    basket.add(first);
    basket.add(second);
    expect(basket.count, 3);
    expect(basket.order.subtotal, 8500);
    expect(basket.applyCoupon('nope'), isFalse);
    expect(basket.applyCoupon(' welcome10 '), isTrue);
    expect(basket.order.discount, 850);
    expect(basket.order.total, 7650);
    final snapshot = basket.order;
    basket.decrease(first);
    expect(basket.order.total, 5400);
    expect(snapshot.total, 7650);
    basket.remove(second);
    basket.decrease(first);
    expect(basket.count, 0);
    expect(basket.coupon, isNull);
    basket.dispose();
  });

  testWidgets('Add a product, enter coupon, checkout and clear the cart',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: const HomePage(), onGenerateRoute: generateRoute));
    final add = find.widgetWithText(OutlinedButton, 'เพิ่มลงตะกร้า').first;
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(cart.count, 1);
    await tester.tap(find.text('ตะกร้า (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(CartPage), findsOneWidget);
    await tester.tap(find.text('ใช้คูปอง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('ใช้โค้ดส่วนลด'));
    await tester.pumpAndSettle();
    expect(
        find.text('ไม่พบโค้ดนี้ กรุณาตรวจสอบแล้วลองอีกครั้ง'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'WELCOME10');
    await tester.tap(find.text('ใช้โค้ดส่วนลด'));
    await tester.pumpAndSettle();
    expect(find.text('ยอดสุทธิ 22.50 บาท'), findsOneWidget);
    await tester.ensureVisible(find.text('ไปชำระเงิน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ไปชำระเงิน'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ยืนยันการชำระเงินทดลอง'), 150);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'ยืนยันการชำระเงินทดลอง'))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.text('50 บาท'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 บาท'));
    await tester.pumpAndSettle();
    expect(find.text('เงินทอน 27.50 บาท'), findsOneWidget);
    await tester.ensureVisible(find.text('ยืนยันการชำระเงินทดลอง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันการชำระเงินทดลอง'));
    await tester.pumpAndSettle();
    expect(find.text('ทำรายการทดลองสำเร็จ'), findsOneWidget);
    expect(cart.count, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Categories and search filter products together', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: const HomePage(), onGenerateRoute: generateRoute));
    await tester.ensureVisible(find.text('เครื่องดื่ม').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'เครื่องดื่ม'));
    await tester.pumpAndSettle();
    expect(find.text('เครื่องดื่ม · 2 รายการ'), findsOneWidget);
    expect(find.text('Paracetamol 500 mg'), findsNothing);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ไม่มีสินค้านี้');
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบสินค้าที่ค้นหา'), findsOneWidget);
    await tester.ensureVisible(find.text('ดูสินค้าทั้งหมด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ดูสินค้าทั้งหมด'));
    await tester.pumpAndSettle();
    expect(find.text('ทั้งหมด · ${medicines.length} รายการ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
