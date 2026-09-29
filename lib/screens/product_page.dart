import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../widgets/medicine_image.dart';
import '../state/cart.dart';
import '../widgets/cart_button.dart';
import 'cart_page.dart';
import 'coupon_page.dart';

class ProductPage extends StatelessWidget {
  final Medicine medicine;

  const ProductPage({
    super.key,
    required this.medicine,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("รายละเอียดสินค้า"),
          actions: const [CartButton()],
          backgroundColor: Colors.green,
        ),
        body: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(children: [
                  // รูปยา

                  Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20)),
                    child: MedicineImage(medicine: medicine),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    medicine.detail,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),

                  if (medicine.warning != null) ...[
                    const SizedBox(height: 16),
                    const Text('คำเตือน',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(medicine.warning!),
                  ],
                  const SizedBox(height: 25),

                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        const Text(
                          "ราคา",
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          "${medicine.price} บาท",
                          style: const TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        )
                      ])),

                  const SizedBox(height: 30),

                  // Coupon

                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          minimumSize: const Size(double.infinity, 55)),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const CouponPage())),
                      child: const Text(
                        "ใช้คูปอง",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      )),

                  const SizedBox(height: 30),

                  FilledButton.icon(
                      onPressed: () {
                        final added = cart.add(medicine);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(added
                                ? 'เพิ่มลงตะกร้าแล้ว'
                                : 'สินค้าคงเหลือไม่เพียงพอ')));
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('เพิ่มลงตะกร้า')),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const CartPage())),
                      child: const Text('ดูตะกร้าและชำระเงิน')),
                ]))));
  }
}
