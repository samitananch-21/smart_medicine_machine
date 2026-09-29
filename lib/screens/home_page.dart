import 'dart:async';
import 'package:flutter/material.dart';
import '../state/catalog.dart';
import '../services/backend_client.dart';
import '../data/medicine_data.dart';
import '../widgets/medicine_card.dart';
import '../widgets/cart_button.dart';
import 'coupon_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selected = 'ทั้งหมด';
  String query = '';
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    catalog.addListener(_catalogChanged);
    unawaited(catalog.refresh());
  }

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    catalog.removeListener(_catalogChanged);
    search.dispose();
    super.dispose();
  }

  static const categories = {
    'ทั้งหมด': Icons.grid_view_rounded,
    'ยาและบรรเทาอาการ': Icons.medication_outlined,
    'ทำแผลและปฐมพยาบาล': Icons.healing,
    'วิตามินและสุขภาพ': Icons.favorite_outline,
    'ของใช้ส่วนตัว': Icons.spa_outlined,
    'เครื่องดื่ม': Icons.local_drink_outlined,
  };
  @override
  Widget build(BuildContext context) {
    final items = medicines
        .where((m) =>
            (selected == 'ทั้งหมด' || m.category == selected) &&
            ('${m.name} ${m.detail}')
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: const Text('PharmaCare+',
              style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                tooltip: 'แอดมิน',
                onPressed: () => Navigator.pushNamed(context, '/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined)),
            IconButton(
                tooltip: 'อัปเดตสินค้า',
                onPressed: catalog.loading ? null : catalog.refresh,
                icon: const Icon(Icons.refresh)),
            const CartButton(),
          ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (backend.enabled && catalog.loading)
                          const LinearProgressIndicator(),
                        if (backend.enabled && catalog.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                                'ยังโหลดข้อมูลล่าสุดไม่ได้: ${catalog.error}\nแตะปุ่มอัปเดตสินค้าเพื่อลองใหม่',
                                style:
                                    const TextStyle(color: Colors.deepOrange)),
                          ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xffe3f2e7), Colors.white]),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xffc8dfcf)),
                          ),
                          child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 24,
                              runSpacing: 16,
                              children: [
                                const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('PHARMACARE+  /  SELF SERVICE',
                                          style: TextStyle(
                                              fontSize: 12,
                                              letterSpacing: 1.5,
                                              color: Color(0xff57836b))),
                                      SizedBox(height: 8),
                                      Text('เลือกสินค้าจากตู้ยา',
                                          style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xff084b38))),
                                      SizedBox(height: 6),
                                      Text(
                                          'แตะดูรายละเอียด แล้วเพิ่มสินค้าที่ต้องการลงตะกร้า'),
                                    ]),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                        color: const Color(0xff087f58),
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    child: const Text(
                                        '24 ชม.  •  ดูแลคุณทุกวัน',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold))),
                              ]),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                            controller: search,
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'ค้นหาชื่อสินค้า หรือรายละเอียด',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder()),
                            onChanged: (value) =>
                                setState(() => query = value.trim())),
                        const SizedBox(height: 16),
                        const Text('เลือกตามหมวดหมู่',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: categories.entries
                                .map((e) => ChoiceChip(
                                      avatar: Icon(e.value, size: 18),
                                      label: Text(e.key),
                                      selected: selected == e.key,
                                      onSelected: (_) =>
                                          setState(() => selected = e.key),
                                    ))
                                .toList()),
                        const SizedBox(height: 24),
                        const _CouponBanner(),
                        const SizedBox(height: 24),
                        Text('$selected · ${items.length} รายการ',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 18),
                        if (items.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(children: [
                                const Icon(Icons.search_off, size: 56),
                                const Text('ไม่พบสินค้าที่ค้นหา'),
                                TextButton(
                                    onPressed: () => setState(() {
                                          query = '';
                                          selected = 'ทั้งหมด';
                                          search.clear();
                                        }),
                                    child: const Text('ดูสินค้าทั้งหมด')),
                              ])),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Color(0xffc8dfd3),
                                  Color(0xffedf6ee)
                                ]),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: const Color(0xff9abbab), width: 2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x180b553c),
                                  blurRadius: 22,
                                  offset: Offset(0, 8))
                            ],
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                    padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                                    child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 16,
                                        children: [
                                          Text('✚  PharmaCare+',
                                              style: TextStyle(
                                                  color: Color(0xff084b38),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 18)),
                                          Text('ช่องสินค้า',
                                              style: TextStyle(
                                                  color: Color(0xff587b69))),
                                        ])),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xffe0eee6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xffb5d2c1))),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                    final columns = (constraints.maxWidth / 210)
                                        .floor()
                                        .clamp(1, 4);
                                    final width = (constraints.maxWidth -
                                            12 * (columns - 1)) /
                                        columns;
                                    return Wrap(
                                        spacing: 12,
                                        runSpacing: 20,
                                        children: items
                                            .map((m) => SizedBox(
                                                  width: width,
                                                  child: MedicineCard(
                                                      medicine: m,
                                                      slot:
                                                          'A${(medicines.indexOf(m) + 1).toString().padLeft(2, '0')}',
                                                      onTap: () =>
                                                          Navigator.pushNamed(
                                                              context,
                                                              '/product',
                                                              arguments: m)),
                                                ))
                                            .toList());
                                  }),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                    child: Container(
                                  width: 260,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xff254e40),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xff82b49a),
                                          width: 3)),
                                  child: const Text(
                                      'PharmaCare+  •  ดูแลใกล้คุณ',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(color: Color(0xffd9eee1))),
                                )),
                              ]),
                        ),
                        const SizedBox(height: 32),
                      ])))),
    );
  }
}

class _CouponBanner extends StatelessWidget {
  const _CouponBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffedf8f0), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffc8dfcf)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final description = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffd8eee0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xff087f58),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สิทธิพิเศษสำหรับคุณ',
                    style: TextStyle(
                      color: Color(0xff084b38),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'คูปองทดลอง WELCOME10 ลด 10%',
                    style: TextStyle(color: Color(0xff587b69)),
                  ),
                ],
              ),
            ),
          ],
        );
        final action = OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CouponPage()),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xff087f58),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xffb5d2c1)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('กรอกโค้ดคูปอง'),
        );
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [description, const SizedBox(height: 14), action],
          );
        }
        return Row(
          children: [
            Expanded(child: description),
            const SizedBox(width: 20),
            action,
          ],
        );
      }),
    );
  }
}
