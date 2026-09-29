import 'package:flutter/material.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xffeffaf5),
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120,
            height: 120,
            decoration:
                BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(
              Icons.check,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "ชำระเงินสำเร็จ",
            style: TextStyle(
                fontSize: 35, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            "กำลังจ่ายสินค้าออกจากตู้",
            style: TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(250, 60)),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                "กลับหน้าหลัก",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ))
        ])));
  }
}
