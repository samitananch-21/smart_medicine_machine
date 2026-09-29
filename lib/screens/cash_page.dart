import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../widgets/cash_selector.dart';
import 'success_page.dart';

class CashPage extends StatefulWidget {
  final Medicine medicine;

  const CashPage({
    super.key,
    required this.medicine,
  });

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  double money = 0;

  @override
  Widget build(BuildContext context) {
    double change = money - widget.medicine.price;

    return Scaffold(
        appBar: AppBar(
          title: const Text("ชำระด้วยเงินสด"),
          backgroundColor: Colors.green,
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(children: [
              const Icon(
                Icons.payments,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                widget.medicine.name,
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                "ราคา ${widget.medicine.price} บาท",
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "ใส่เงินแล้ว ${money.toStringAsFixed(2)} บาท",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),
              CashSelector(onInsert: (value) => setState(() => money += value)),
              const SizedBox(height: 30),
              Text(
                change >= 0
                    ? "เงินทอน ${change.toStringAsFixed(2)} บาท"
                    : "กรุณาใส่เงินเพิ่ม",
                style: TextStyle(
                    fontSize: 22,
                    color: change >= 0 ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: change >= 0
                          ? () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SuccessPage()));
                            }
                          : null,
                      child: const Text(
                        "ยืนยันการชำระเงิน",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      )))
            ])));
  }
}
