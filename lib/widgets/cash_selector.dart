import 'package:flutter/material.dart';

/// Simulated denominations in baht, shared by both cash checkout screens.
class CashSelector extends StatelessWidget {
  final ValueChanged<int>? onInsert;
  const CashSelector({super.key, required this.onInsert});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เลือกเงินจำลองเพื่อใส่เงิน',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xff124c3c))),
          const SizedBox(height: 6),
          const Text('แตะจำนวนเงินที่ต้องการ เพิ่มได้หลายครั้ง',
              style: TextStyle(color: Color(0xff668174), fontSize: 13)),
          const SizedBox(height: 18),
          const Text('เหรียญ',
              style: TextStyle(
                  color: Color(0xff668174), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final value in [1, 2, 5, 10]) denomination(value, coin: true)
          ]),
          const SizedBox(height: 22),
          const Text('ธนบัตร',
              style: TextStyle(
                  color: Color(0xff668174), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final value in [20, 50, 100, 500, 1000])
              denomination(value, coin: false)
          ]),
        ],
      );

  Widget denomination(int value, {required bool coin}) {
    final color = coin ? const Color(0xff94732f) : const Color(0xff34795a);
    return Semantics(
        label: coin ? 'เหรียญ' : 'ธนบัตร',
        child: OutlinedButton(
          key: ValueKey('cash-$value'),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor:
                coin ? const Color(0xfffffcf3) : const Color(0xfff1f8f3),
            side: BorderSide(
                color:
                    coin ? const Color(0xffe2d6b5) : const Color(0xffc3dcca)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onInsert == null ? null : () => onInsert!(value),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: coin ? 38 : 52,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: coin
                        ? [const Color(0xfff7e7b7), const Color(0xffe9d49b)]
                        : [const Color(0xffd1e8d6), const Color(0xffb7d5c1)]),
                shape: coin ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: coin ? null : BorderRadius.circular(5),
                border: Border.all(color: color.withAlpha(90)),
              ),
              child: Icon(
                  coin
                      ? Icons.monetization_on_outlined
                      : Icons.payments_outlined,
                  color: color,
                  size: 23),
            ),
            const SizedBox(height: 8),
            Text('$value บาท',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ));
  }
}
