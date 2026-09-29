import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_medicine_machine/models/medicine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_medicine_machine/data/medicine_data.dart';
import 'package:smart_medicine_machine/main.dart';
import 'package:smart_medicine_machine/screens/home_page.dart';
import 'package:smart_medicine_machine/screens/product_page.dart';

void main() {
  for (final size in [const Size(1440, 900), const Size(900, 700)]) {
    testWidgets('Welcome screen and CTA fit desktop $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const PharmaCareApp());
      await tester.pumpAndSettle();
      expect(find.text('ตู้ยาอัจฉริยะ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('เริ่มต้นใช้งาน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เริ่มต้นใช้งาน'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Browse a product using named routes and return home',
      (tester) async {
    await tester.pumpWidget(const PharmaCareApp());
    await tester.ensureVisible(find.text('เริ่มต้นใช้งาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มต้นใช้งาน'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(medicines, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(medicines.first.name), 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        tester.element(find.text(medicines.first.name)),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(medicines.first.name));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPage), findsOneWidget);
    expect(find.text(medicines.first.detail), findsOneWidget);
    expect(find.text('25.0 บาท'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Every product opens with its details', (tester) async {
    for (final medicine in medicines) {
      await tester
          .pumpWidget(MaterialApp(home: ProductPage(medicine: medicine)));
      await tester.pumpAndSettle();
      expect(find.text(medicine.name), findsOneWidget);
      expect(find.text(medicine.detail), findsOneWidget);
      if (medicine.warning != null) {
        expect(find.text(medicine.warning!), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Product route without arguments shows a recoverable message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/product',
      onGenerateRoute: generateRoute,
    ));
    await tester.pumpAndSettle();
    expect(find.text('กรุณากลับไปเลือกสินค้าและวิธีชำระเงิน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payment route receives the selected medicine and payment method',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: generateRoute,
      home: Builder(
          builder: (context) => TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/payment', arguments: {
                  'medicine': medicines.first,
                  'type': 'qr',
                }),
                child: const Text('Open payment'),
              )),
    ));
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    expect(find.text(medicines.first.name), findsOneWidget);
    expect(find.text('ชำระด้วย QR Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Missing image displays a fallback', (tester) async {
    final medicine = Medicine(
      name: 'Missing image',
      detail: 'Test',
      price: 1,
      image: 'assets/images/does_not_exist.png',
    );
    await tester.pumpWidget(MaterialApp(home: ProductPage(medicine: medicine)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Mapped product images exist and can be decoded', () async {
    for (final name in ['Paracetamol 500 mg', 'Loratadine micronized 10 mg']) {
      final medicine = medicines.singleWhere((item) => item.name == name);
      final data = await rootBundle.load(medicine.image);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      ));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      frame.image.dispose();
      codec.dispose();
    }
  });

  for (final size in [const Size(320, 480), const Size(640, 320)]) {
    testWidgets('Small screen and large text work at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget page) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            onGenerateRoute: generateRoute,
            home: page,
          );
      await tester.pumpWidget(const PharmaCareApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const HomePage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(medicines.last.name), 200,
          scrollable: find.byType(Scrollable).first, maxScrolls: 150);
      await Scrollable.ensureVisible(
          tester.element(find.text(medicines.last.name)),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text(medicines.last.name));
      await tester.pumpAndSettle();
      expect(find.text(medicines.last.detail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
