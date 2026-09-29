import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medicine_machine/data/medicine_data.dart';
import 'package:smart_medicine_machine/screens/cash_page.dart';
import 'package:smart_medicine_machine/screens/checkout_page.dart';
import 'package:smart_medicine_machine/state/cart.dart';

void main() {
  for (final size in [const Size(1280, 900), const Size(320, 600)]) {
    testWidgets('Checkout reset and QR selection work at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width < 500 ? 1.5 : 1)),
          child: child!,
        ),
        home: CheckoutPage(order: Order([OrderLine(medicines.first, 2)], null)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('cash-100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cash-100')));
      await tester.pumpAndSettle();
      expect(find.text('ใส่เงินทดลองแล้ว 100.00 บาท'), findsOneWidget);
      await tester.ensureVisible(find.text('เริ่มใส่เงินใหม่'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มใส่เงินใหม่'));
      await tester.pumpAndSettle();
      expect(find.text('ใส่เงินทดลองแล้ว 0.00 บาท'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'ยืนยันการชำระเงินทดลอง'))
              .onPressed,
          isNull);
      await tester.ensureVisible(find.text('QR Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR Code'));
      await tester.pumpAndSettle();
      expect(find.text('ทดลองชำระด้วย QR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final legacy in [false, true]) {
    testWidgets('Every cash denomination adds its value (legacy: $legacy)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: legacy
              ? CashPage(medicine: medicines.first)
              : CheckoutPage(
                  order: Order([OrderLine(medicines.first, 1)], null))));
      var total = 0;
      for (final value in [1, 2, 5, 10, 20, 50, 100, 500, 1000]) {
        final button = find.byKey(ValueKey('cash-$value'));
        await tester.scrollUntilVisible(button, 150);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        total += value;
        // Scroll back to the amount so lazy checkout content is built.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(
            find.text(
                '${legacy ? 'ใส่เงินแล้ว' : 'ใส่เงินทดลองแล้ว'} ${total.toStringAsFixed(2)} บาท'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(total, 1688);
    });
  }
}
