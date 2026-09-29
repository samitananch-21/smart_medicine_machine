import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../state/cart.dart';
import 'medicine_image.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTap;
  final String? slot;
  const MedicineCard(
      {super.key, required this.medicine, required this.onTap, this.slot});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: cart,
      builder: (context, _) => Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xffc6dcd0))),
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (slot != null)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xffe2f0e6),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(slot!,
                                      style: const TextStyle(
                                          color: Color(0xff146746),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                )),
                          const SizedBox(height: 10),
                          SizedBox(
                              height: 145,
                              width: double.infinity,
                              child: MedicineImage(medicine: medicine)),
                          Container(
                              height: 8,
                              margin:
                                  const EdgeInsets.only(top: 10, bottom: 12),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xffe6f4ed),
                                        Color(0xffa9c9b9)
                                      ]))),
                          Text(medicine.category,
                              style: const TextStyle(
                                  color: Color(0xff637a6e), fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(medicine.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('คงเหลือ ${medicine.stock} ชิ้น',
                              style: const TextStyle(
                                  color: Color(0xff637a6e), fontSize: 12)),
                          const SizedBox(height: 12),
                          Text(baht((medicine.price * 100).round()),
                              style: const TextStyle(
                                  fontSize: 20,
                                  color: Color(0xff08715d),
                                  fontWeight: FontWeight.bold)),
                        ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xffe9f5ec),
                        foregroundColor: const Color(0xff086746),
                        side: const BorderSide(color: Color(0xffa1cdb3))),
                    onPressed: !cart.canAdd(medicine)
                        ? null
                        : () {
                            cart.add(medicine);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('เพิ่ม ${medicine.name} ลงตะกร้าแล้ว'),
                                duration: const Duration(seconds: 1)));
                          },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(
                        medicine.stock == 0 ? 'สินค้าหมด' : 'เพิ่มลงตะกร้า'))),
          ])));
}
