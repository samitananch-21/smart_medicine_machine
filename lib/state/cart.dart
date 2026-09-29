import 'package:flutter/foundation.dart';
import '../models/medicine.dart';

class OrderLine {
  final Medicine medicine;
  final int quantity;
  const OrderLine(this.medicine, this.quantity);
  int get total => medicine.priceSatang * quantity;
}

class Order {
  final List<OrderLine> lines;
  final String? coupon;
  Order(Iterable<OrderLine> items, this.coupon)
      : lines = List.unmodifiable(items);
  int get subtotal => lines.fold(0, (sum, line) => sum + line.total);
  int get discount => coupon == 'WELCOME10' ? (subtotal + 5) ~/ 10 : 0;
  int get total => subtotal - discount;
}

class Cart extends ChangeNotifier {
  final Map<String, OrderLine> _items = {};
  Map<String, Medicine>? _catalog;
  String? _coupon;
  List<OrderLine> get lines => List.unmodifiable(_items.values);
  int get count => _items.values.fold(0, (sum, line) => sum + line.quantity);
  String? get coupon => _coupon;
  Order get order => Order(lines, _coupon);
  int quantityOf(Medicine medicine) => _items[medicine.cartKey]?.quantity ?? 0;
  bool canAdd(Medicine medicine) {
    final product = _catalog == null ? medicine : _catalog![medicine.cartKey];
    return product != null &&
        product.active &&
        quantityOf(product) < product.stock &&
        quantityOf(product) < 99;
  }

  bool add(Medicine medicine) {
    if (!canAdd(medicine)) return false;
    final product = _catalog?[medicine.cartKey] ?? medicine;
    _items[product.cartKey] = OrderLine(product, quantityOf(product) + 1);
    notifyListeners();
    return true;
  }

  void decrease(Medicine medicine) {
    final line = _items[medicine.cartKey];
    if (line == null) return;
    if (line.quantity == 1) {
      remove(medicine);
      return;
    }
    _items[medicine.cartKey] = OrderLine(line.medicine, line.quantity - 1);
    notifyListeners();
  }

  void remove(Medicine medicine) {
    _items.remove(medicine.cartKey);
    if (_items.isEmpty) _coupon = null;
    notifyListeners();
  }

  void reconcile(List<Medicine> products) {
    _catalog = {for (final product in products) product.cartKey: product};
    for (final key in _items.keys.toList()) {
      final product = _catalog![key];
      if (product == null || !product.active || product.stock == 0) {
        _items.remove(key);
      } else {
        final quantity = _items[key]!.quantity.clamp(1, product.stock);
        _items[key] = OrderLine(product, quantity);
      }
    }
    if (_items.isEmpty) _coupon = null;
    notifyListeners();
  }

  bool applyCoupon(String code) {
    if (code.trim().toUpperCase() != 'WELCOME10') return false;
    _coupon = 'WELCOME10';
    notifyListeners();
    return true;
  }

  void removeCoupon() {
    _coupon = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _coupon = null;
    notifyListeners();
  }
}

final cart = Cart();
String baht(int satang) => '${(satang / 100).toStringAsFixed(2)} บาท';
