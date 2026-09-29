import 'package:flutter/material.dart';
import '../models/medicine.dart';
import 'success_page.dart';

class QRPage extends StatelessWidget {
  final Medicine medicine;

  const QRPage({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("QR Payment"),
          backgroundColor: Colors.green,
        ),
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(
            Icons.qr_code_2,
            size: 200,
            color: Colors.black,
          ),
          const SizedBox(height: 30),
          Text(
            "ยอดชำระ ${medicine.price} บาท",
            style: const TextStyle(fontSize: 25),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SuccessPage()));
              },
              child: const Text("ชำระแล้ว"))
        ])));
  }
}
