import 'package:flutter/material.dart';
import '../models/medicine.dart';
import 'checkout_page.dart';
import '../state/cart.dart';

class PaymentPage extends StatelessWidget {
  final Medicine medicine;
  final String type;

  const PaymentPage({
    super.key,
    required this.medicine,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("ชำระเงิน"),
          backgroundColor: Colors.green,
        ),
        body: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(children: [
              const Icon(
                Icons.shopping_bag,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 30),
              Text(
                medicine.name,
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                "ยอดชำระ ${medicine.price} บาท",
                style: const TextStyle(
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 50),
              if (type == "qr")
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: Colors.green),
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    label: const Text(
                      "ชำระด้วย QR Code",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CheckoutPage(
                                  order: Order([OrderLine(medicine, 1)], null),
                                  initialMethod: 'qr')));
                    })
              else
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: Colors.orange),
                    icon: const Icon(Icons.money, color: Colors.white),
                    label: const Text(
                      "ชำระด้วยเงินสด",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CheckoutPage(
                                  order:
                                      Order([OrderLine(medicine, 1)], null))));
                    })
            ])));
  }
}
