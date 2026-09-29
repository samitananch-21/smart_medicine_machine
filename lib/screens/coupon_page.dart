import 'package:flutter/material.dart';
import '../state/cart.dart';

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});
  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  final controller = TextEditingController(text: cart.coupon);
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void apply() {
    if (cart.applyCoupon(controller.text)) {
      Navigator.pop(context);
    } else {
      setState(() => error = 'ไม่พบโค้ดนี้ กรุณาตรวจสอบแล้วลองอีกครั้ง');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('คูปองส่วนลด')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                    padding: const EdgeInsets.all(24),
                    shrinkWrap: true,
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          size: 72, color: Color(0xff10866b)),
                      const SizedBox(height: 24),
                      const Text('เพิ่มความคุ้มค่าให้ตะกร้า',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                          'คูปองทดลอง WELCOME10 ลด 10% จากยอดสินค้าทั้งหมด ใช้ได้ครั้งละ 1 โค้ด'),
                      const SizedBox(height: 24),
                      TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                              labelText: 'กรอกโค้ดคูปอง',
                              border: const OutlineInputBorder(),
                              errorText: error),
                          onSubmitted: (_) => apply()),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: apply, child: const Text('ใช้โค้ดส่วนลด')),
                      if (cart.coupon != null)
                        TextButton(
                            onPressed: () {
                              cart.removeCoupon();
                              Navigator.pop(context);
                            },
                            child: const Text('นำคูปองออก')),
                    ]))),
      );
}
