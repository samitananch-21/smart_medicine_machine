import 'package:flutter/foundation.dart';
import '../data/medicine_data.dart';
import '../services/backend_client.dart';
import 'cart.dart';

class Catalog extends ChangeNotifier {
  bool loading = false;
  String? error;
  bool loaded = false;
  Future<void>? _pending;
  Future<void> refresh() {
    if (!backend.enabled) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final products = await backend.fetchProducts();
      medicines = products;
      cart.reconcile(products);
      loaded = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

final catalog = Catalog();
