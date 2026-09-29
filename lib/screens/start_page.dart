import 'package:flutter/material.dart';

const _green = Color(0xff176b4b);
const _text = Color(0xff20382d);
const _secondary = Color(0xff63776a);

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfffafbf8),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: compact ? 20 : 48, vertical: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/admin'),
                              icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 18),
                              label: const Text('สำหรับผู้ดูแล'))),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: compact ? 32 : 44),
                        child: Center(
                            child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: compact ? 24 : 56,
                                vertical: compact ? 36 : 46),
                            decoration: BoxDecoration(
                              color: const Color(0xffedf5ed),
                              borderRadius: BorderRadius.circular(28),
                              border:
                                  Border.all(color: const Color(0xffdce9dc)),
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(22)),
                                    child: const Icon(Icons.medication_outlined,
                                        size: 36, color: _green),
                                  ),
                                  const SizedBox(height: 24),
                                  Text('ตู้ยาอัจฉริยะ',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: compact ? 34 : 46,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700,
                                          color: _text)),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'เลือกยาและของใช้เพื่อสุขภาพ\nจากตู้บริการอัตโนมัติ',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 18,
                                          height: 1.7,
                                          color: _secondary)),
                                  const SizedBox(height: 30),
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 320),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _green,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 22, vertical: 20),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                          ),
                                          onPressed: () =>
                                              Navigator.pushReplacementNamed(
                                                  context, '/home'),
                                          child: const Wrap(
                                              alignment: WrapAlignment.center,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 10,
                                              runSpacing: 4,
                                              children: [
                                                Text('เริ่มต้นใช้งาน',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 20)
                                              ]),
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                  const Text('แตะเพื่อเลือกสินค้า',
                                      style: TextStyle(
                                          fontSize: 13, color: _secondary)),
                                ]),
                          ),
                        )),
                      ),
                      Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Column(children: [
                                const Text('ใช้งานง่ายใน 3 ขั้นตอน',
                                    style: TextStyle(
                                        fontSize: 14, color: _secondary)),
                                const SizedBox(height: 18),
                                Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 24,
                                    runSpacing: 16,
                                    children: [
                                      _step('01', 'เลือกสินค้า'),
                                      _step('02', 'ตรวจสอบตะกร้า'),
                                      _step('03', 'ชำระเงิน'),
                                    ]),
                              ]))),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );

  Widget _header() => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 14,
              children: [
                Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 22)),
                      const Text('PharmaCare+',
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: _text)),
                    ]),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                        color: const Color(0xffedf5ed),
                        borderRadius: BorderRadius.circular(24)),
                    child: const Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Icon(Icons.schedule_outlined,
                              size: 17, color: _green),
                          Text('บริการ 24 ชั่วโมง',
                              style: TextStyle(fontSize: 14, color: _green)),
                        ])),
              ],
            )),
      ));

  Widget _step(String number, String title) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffdce7dc))),
              child: Text(number,
                  style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
          Text(title, style: const TextStyle(color: _text, fontSize: 14)),
        ],
      );
}
