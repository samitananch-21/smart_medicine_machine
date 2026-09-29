import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backend_client.dart';
import '../state/catalog.dart';
import '../state/cart.dart';
import '../widgets/cash_selector.dart';
import '../widgets/medicine_image.dart';

const _ink = Color(0xff124c3c);
const _muted = Color(0xff668174);

class CheckoutPage extends StatefulWidget {
  final Order order;
  final String initialMethod;
  const CheckoutPage(
      {super.key, required this.order, this.initialMethod = 'cash'});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late String method;
  int paid = 0;
  bool completed = false;
  bool submitting = false;
  bool blockedOrder = false;
  String? error;
  Map<String, dynamic>? _pendingPayload;
  bool get locked =>
      submitting || completed || blockedOrder || _pendingPayload != null;

  @override
  void initState() {
    super.initState();
    method = widget.initialMethod;
  }

  Future<void> complete() async {
    if (completed ||
        submitting ||
        blockedOrder ||
        widget.order.lines.isEmpty ||
        (method == 'cash' && paid < widget.order.total)) {
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    String? orderId;
    try {
      if (backend.enabled) {
        _pendingPayload ??= {
          'request_id': newRequestId(),
          'items': widget.order.lines
              .map((line) => {
                    'product_id': line.medicine.id,
                    'quantity': line.quantity,
                    'unit_price_satang': line.medicine.priceSatang,
                  })
              .toList(),
          'coupon': widget.order.coupon,
          'payment_method': method,
          'paid_satang': method == 'cash' ? paid : widget.order.total,
        };
        final result = await backend.submitOrder(_pendingPayload!);
        if (result['status'] == 'cancelled') {
          throw const BackendException(
              'คำสั่งซื้อนี้ถูกยกเลิกแล้ว กรุณากลับไปตรวจสอบตะกร้า', 409);
        }
        if (result['id'] is! String ||
            (result['id'] as String).isEmpty ||
            !['pending', 'fulfilled'].contains(result['status'])) {
          throw const BackendException(
              'ยังยืนยันผลคำสั่งซื้อไม่ได้ กรุณาลองส่งรายการเดิมอีกครั้ง');
        }
        orderId = result['id'] as String;
      }
      completed = true;
      _pendingPayload = null;
      cart.clear();
      unawaited(catalog.refresh());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
              builder: (_) => _OrderComplete(orderId: orderId)),
          (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        if (e is BackendException &&
            e.status != null &&
            e.status! >= 400 &&
            e.status! < 500) {
          _pendingPayload = null;
          blockedOrder = true;
        }
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !submitting && _pendingPayload == null,
      child: Scaffold(
        backgroundColor: const Color(0xffeff5f0),
        appBar: AppBar(
          backgroundColor: const Color(0xffeff5f0),
          title: const Text('ชำระเงิน',
              style: TextStyle(color: _ink, fontWeight: FontWeight.bold)),
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 20),
                child: Icon(Icons.local_pharmacy_outlined, color: _ink))
          ],
        ),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('อีกขั้นเดียว ก็ครบแล้ว',
                          style: TextStyle(
                              fontSize: 30,
                              color: _ink,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                          'ตรวจสอบสินค้า เลือกวิธีชำระเงิน แล้วทำรายการต่อได้เลย',
                          style: TextStyle(color: _muted, fontSize: 16)),
                      const SizedBox(height: 20),
                      Wrap(spacing: 12, runSpacing: 8, children: [
                        _step('1', 'เลือกสินค้า', false),
                        _step('2', 'ชำระเงิน', true),
                        _step('3', 'เสร็จสิ้น', false),
                      ]),
                      const SizedBox(height: 24),
                      LayoutBuilder(builder: (context, constraints) {
                        if (constraints.maxWidth < 900) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _summary(),
                                const SizedBox(height: 20),
                                _payment(),
                              ]);
                        }
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 4, child: _summary()),
                              const SizedBox(width: 24),
                              Expanded(flex: 6, child: _payment()),
                            ]);
                      }),
                    ],
                  ))),
        )),
      ));

  Widget _step(String number, String label, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: active ? _ink : Colors.white,
            borderRadius: BorderRadius.circular(30)),
        child: Text('$number  $label',
            style: TextStyle(
                color: active ? Colors.white : _muted,
                fontWeight: FontWeight.w600)),
      );

  Widget _surface(Widget child) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xffdce8df)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080e4f35),
                  blurRadius: 20,
                  offset: Offset(0, 8))
            ]),
        child: child,
      );

  Widget _summary() => _surface(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('สรุปคำสั่งซื้อ',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 4),
        Text(
            '${widget.order.lines.fold<int>(0, (n, line) => n + line.quantity)} ชิ้นในรายการของคุณ',
            style: const TextStyle(color: _muted)),
        const SizedBox(height: 24),
        for (final line in widget.order.lines)
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 64,
                    height: 72,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xfff2f7f3),
                        borderRadius: BorderRadius.circular(12)),
                    child: MedicineImage(medicine: line.medicine)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(line.medicine.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: _ink)),
                      const SizedBox(height: 5),
                      Text('จำนวน ${line.quantity} ชิ้น',
                          style: const TextStyle(color: _muted, fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(baht(line.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: _ink)),
                    ])),
              ])),
        const Divider(height: 24, color: Color(0xffe1eae3)),
        _amountRow('ยอดสินค้า', baht(widget.order.subtotal)),
        const SizedBox(height: 12),
        _amountRow('ส่วนลด', '-${baht(widget.order.discount)}'),
        if (widget.order.coupon != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('คูปอง ${widget.order.coupon}',
                  style: const TextStyle(color: Color(0xff17865b)))),
        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color(0xffedf6ef),
                borderRadius: BorderRadius.circular(16)),
            child: Text('ยอดชำระ ${baht(widget.order.total)}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: _ink))),
        const SizedBox(height: 16),
        const Text('โหมดทดลอง • ยังไม่รับเงินจริงหรือสั่งจ่ายสินค้า',
            style: TextStyle(fontSize: 12, height: 1.6, color: _muted)),
      ]));

  Widget _amountRow(String label, String value) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(label, style: const TextStyle(color: _muted)),
          Text(value,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w600))
        ],
      );

  Widget _payment() => _surface(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('เลือกวิธีชำระเงิน',
            style: TextStyle(
                fontSize: 22, color: _ink, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _method('cash', 'เงินสด', Icons.payments_outlined),
          _method('qr', 'QR Code', Icons.qr_code_rounded),
        ]),
        const SizedBox(height: 24),
        if (method == 'cash') ...[
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xff185b47), Color(0xff0b3e30)]),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('CASH RECEIVED / เงินที่ใส่',
                        style: TextStyle(
                            color: Color(0xffb9dbc7),
                            fontSize: 12,
                            letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Text('ใส่เงินทดลองแล้ว ${baht(paid)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            value: widget.order.total <= 0
                                ? 1
                                : (paid / widget.order.total).clamp(0.0, 1.0),
                            minHeight: 6,
                            color: const Color(0xffbfe6af),
                            backgroundColor: const Color(0xff386d57))),
                    const SizedBox(height: 12),
                    Text(
                        paid >= widget.order.total
                            ? 'เงินทอน ${baht(paid - widget.order.total)}'
                            : 'ยังขาด ${baht(widget.order.total - paid)}',
                        style: const TextStyle(
                            color: Color(0xffd1edcf),
                            fontWeight: FontWeight.w600)),
                  ])),
          const SizedBox(height: 24),
          CashSelector(
              onInsert: locked
                  ? null
                  : (value) => setState(() => paid += value * 100)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: paid == 0 || locked
                      ? null
                      : () => setState(() => paid = 0),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('เริ่มใส่เงินใหม่'))),
        ] else ...[
          Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: const Color(0xfff2f7f3),
                  borderRadius: BorderRadius.circular(20)),
              child: const Column(children: [
                Icon(Icons.qr_code_2, size: 112, color: _muted),
                SizedBox(height: 16),
                Text('ทดลองชำระด้วย QR',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ink)),
                SizedBox(height: 10),
                Text(
                    'ยังไม่มี QR สำหรับรับเงินจริง ใช้ปุ่มด้านล่างเพื่อทดลองขั้นตอนเท่านั้น',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted)),
              ])),
        ],
        const SizedBox(height: 16),
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: Colors.deepOrange)),
          const SizedBox(height: 12),
          if (_pendingPayload != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'กดยืนยันอีกครั้งเพื่อตรวจผลรายการเดิม กรุณาอยู่หน้านี้ระหว่างรอ เพื่อป้องกันการสั่งซื้อซ้ำ',
                  style: TextStyle(color: _muted)),
            ),
          if (blockedOrder)
            TextButton(
                onPressed: () async {
                  await catalog.refresh();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('กลับไปตรวจตะกร้าและราคาล่าสุด')),
        ],
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff087b53),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 20)),
          onPressed: completed ||
                  submitting ||
                  blockedOrder ||
                  widget.order.lines.isEmpty ||
                  (method == 'cash' && paid < widget.order.total)
              ? null
              : complete,
          child: Text(
              submitting ? 'กำลังบันทึกคำสั่งซื้อ…' : 'ยืนยันการชำระเงินทดลอง',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ]));

  Widget _method(String value, String label, IconData icon) => ChoiceChip(
        selected: method == value,
        onSelected: locked ? null : (_) => setState(() => method = value),
        showCheckmark: false,
        selectedColor: const Color(0xffe0f1e5),
        backgroundColor: Colors.white,
        side: BorderSide(
            color: method == value
                ? const Color(0xff218c64)
                : const Color(0xffd5e2d8),
            width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        avatar: Icon(icon, color: _ink, size: 22),
        label: Text(label,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.bold)),
      );
}

class _OrderComplete extends StatelessWidget {
  final String? orderId;
  const _OrderComplete({this.orderId});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline,
                    size: 90, color: Colors.teal),
                const Text('ทำรายการทดลองสำเร็จ',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('ไม่มีการเรียกเก็บเงินจริงหรือจ่ายสินค้า'),
                if (orderId != null)
                  Text('เลขคำสั่งซื้อ $orderId\nบันทึกเข้าระบบหลังบ้านแล้ว',
                      textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('กลับหน้าร้าน')),
              ]))));
}
