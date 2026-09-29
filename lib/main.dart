import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_client.dart';
import 'state/catalog.dart';
import 'screens/admin/admin_page.dart';
import 'screens/checkout_page.dart';
import 'state/cart.dart';

import 'models/medicine.dart';
import 'screens/start_page.dart';
import 'screens/home_page.dart';
import 'screens/product_page.dart';
import 'screens/payment_page.dart';
import 'screens/success_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  backend.enabled = true;
  unawaited(catalog.refresh());
  runApp(const PharmaCareApp());
}

class PharmaCareApp extends StatelessWidget {
  const PharmaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "PharmaCare+",
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff5f7f2),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xfff5f7f2),
            foregroundColor: Color(0xff123e35)),
        cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18))),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff10A86B),
        ),
      ),
      initialRoute: "/",
      onGenerateRoute: generateRoute,
      routes: {
        "/admin": (context) => const AdminPage(),
        "/": (context) => const StartPage(),
        "/home": (context) => const HomePage(),
        "/success": (context) => const SuccessPage(),
      },
    );
  }
}

// Product routes require the selected medicine; payment also requires a method.
Route<void> generateRoute(RouteSettings settings) {
  final arguments = settings.arguments;
  Widget? page;
  if (arguments is Medicine) {
    switch (settings.name) {
      case '/product':
        page = ProductPage(medicine: arguments);
      case '/qr':
        page = CheckoutPage(
            order: Order([OrderLine(arguments, 1)], null), initialMethod: 'qr');
      case '/cash':
        page = CheckoutPage(order: Order([OrderLine(arguments, 1)], null));
    }
  } else if (settings.name == '/payment' && arguments is Map) {
    final medicine = arguments['medicine'];
    final type = arguments['type'];
    if (medicine is Medicine && (type == 'qr' || type == 'cash')) {
      page = PaymentPage(medicine: medicine, type: type as String);
    }
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (context) =>
        page ??
        Scaffold(
          appBar: AppBar(title: const Text('ไม่สามารถเปิดหน้านี้ได้')),
          body: const Center(
              child: Text('กรุณากลับไปเลือกสินค้าและวิธีชำระเงิน')),
        ),
  );
}
