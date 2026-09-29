import 'package:flutter/material.dart';
import '../state/cart.dart';
import '../widgets/medicine_image.dart';
import 'coupon_page.dart';
import 'checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final order = cart.order;
        return Scaffold(
          appBar: AppBar(title: Text('ตะกร้าของคุณ (${cart.count})')),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: cart.count == 0
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 80, color: Colors.teal),
                              const SizedBox(height: 20),
                              const Text(
                                  'ตะกร้ายังว่าง เลือกสินค้าที่คุณต้องการได้เลย'),
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('เลือกซื้อสินค้า')),
                            ])
                      : ListView(padding: const EdgeInsets.all(24), children: [
                          for (final line in order.lines)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            SizedBox(
                                                width: 60,
                                                height: 60,
                                                child: MedicineImage(
                                                    medicine: line.medicine)),
                                            const SizedBox(width: 16),
                                            Expanded(
                                                child: Text(line.medicine.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold))),
                                            IconButton(
                                                tooltip:
                                                    'ลบ ${line.medicine.name}',
                                                onPressed: () =>
                                                    cart.remove(line.medicine),
                                                icon: const Icon(
                                                    Icons.delete_outline))
                                          ]),
                                          Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 12,
                                              children: [
                                                IconButton(
                                                    tooltip:
                                                        'ลดจำนวน ${line.medicine.name}',
                                                    onPressed: () =>
                                                        cart.decrease(
                                                            line.medicine),
                                                    icon: const Icon(Icons
                                                        .remove_circle_outline)),
                                                Text('${line.quantity}'),
                                                IconButton(
                                                    tooltip:
                                                        'เพิ่มจำนวน ${line.medicine.name}',
                                                    onPressed: cart.canAdd(
                                                            line.medicine)
                                                        ? () => cart
                                                            .add(line.medicine)
                                                        : null,
                                                    icon: const Icon(Icons
                                                        .add_circle_outline)),
                                                Text(baht(line.total)),
                                              ]),
                                        ]))),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => const CouponPage())),
                              icon: const Icon(
                                  Icons.confirmation_number_outlined),
                              label: Text(cart.coupon ?? 'ใช้คูปอง')),
                          const SizedBox(height: 20),
                          Text('ยอดสินค้า ${baht(order.subtotal)}'),
                          Text('ส่วนลด ${baht(order.discount)}'),
                          const SizedBox(height: 12),
                          Text('ยอดสุทธิ ${baht(order.total)}',
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          CheckoutPage(order: order))),
                              child: const Text('ไปชำระเงิน')),
                        ]))),
        );
      });
}
