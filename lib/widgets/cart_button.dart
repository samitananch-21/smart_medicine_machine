import 'package:flutter/material.dart';
import '../state/cart.dart';
import '../screens/cart_page.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          void open() => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const CartPage()));
          if (MediaQuery.sizeOf(context).width < 500) {
            return IconButton(
                tooltip: 'ตะกร้า (${cart.count})',
                onPressed: open,
                icon: Badge(
                    label: Text('${cart.count}'),
                    child: const Icon(Icons.shopping_bag_outlined)));
          }
          return TextButton.icon(
              onPressed: open,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text('ตะกร้า (${cart.count})'));
        },
      );
}
