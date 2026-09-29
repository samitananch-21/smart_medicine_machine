import 'package:flutter/material.dart';

import '../../models/medicine.dart';
import '../../services/backend_client.dart';
import '../../state/cart.dart';
import '../../state/catalog.dart';
import '../../widgets/medicine_image.dart';
import 'admin_widgets.dart';
import 'product_editor.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _loginForm = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  List<Medicine> _products = [];
  List<Map<String, dynamic>> _orders = [];
  String _query = '';
  String _orderFilter = 'all';
  int _tab = 0;
  bool _obscurePassword = true;
  bool _loggingIn = false;
  bool _loggingOut = false;
  bool _loading = false;
  String? _updatingOrder;
  String? _error;

  bool get _busy => _loading || _loggingOut || _updatingOrder != null;

  @override
  void initState() {
    super.initState();
    if (backend.isLoggedIn) _refresh();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(Object error) => error is BackendException
      ? error.message
      : 'เชื่อมต่อหลังบ้านไม่สำเร็จ กรุณาลองอีกครั้ง';

  Future<void> _login() async {
    if (_loggingIn || !_loginForm.currentState!.validate()) return;
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      await backend.login(_username.text.trim(), _password.text);
      if (!mounted) return;
      _password.clear();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<bool> _refresh({bool refreshCatalog = false}) async {
    if (!backend.isLoggedIn) {
      if (mounted) setState(() {});
      return false;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        backend.fetchAdminProducts(),
        backend.fetchOrders(),
      ]);
      if (!mounted) return false;
      setState(() {
        _products = results[0] as List<Medicine>;
        _orders = results[1] as List<Map<String, dynamic>>;
      });
      if (refreshCatalog) {
        await catalog.refresh();
        if (catalog.error != null) throw BackendException(catalog.error!);
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    String? logoutError;
    try {
      await backend.logout();
    } catch (_) {
      logoutError =
          'ออกจากระบบบนอุปกรณ์แล้ว แต่ติดต่อเซิร์ฟเวอร์เพื่อปิดเซสชันไม่สำเร็จ';
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
          _products = [];
          _orders = [];
          _query = '';
          _error = logoutError;
          _password.clear();
        });
      }
    }
  }

  Future<void> _editProduct([Medicine? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditor(medicine: product),
    );
    if (!mounted) return;
    setState(() {});
    if (!backend.isLoggedIn) {
      setState(() => _error = 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง');
      return;
    }
    if (saved == true) {
      final refreshed = await _refresh(refreshCatalog: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(refreshed
            ? 'บันทึกสินค้าและอัปเดตหน้าร้านแล้ว'
            : 'บันทึกสินค้าแล้ว แต่โหลดข้อมูลล่าสุดไม่สำเร็จ กรุณารีเฟรช'),
      ));
    }
  }

  Future<void> _updateOrder(Map<String, dynamic> order, String status) async {
    if (_busy) return;
    if (status == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยกเลิกคำสั่งซื้อนี้?'),
          content: const Text(
              'ระบบจะคืนจำนวนสินค้าในคำสั่งซื้อนี้เข้าสู่สต็อก การเปลี่ยนสถานะนี้ย้อนกลับไม่ได้'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('กลับ')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยันยกเลิกคำสั่งซื้อ')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final id = order['id'].toString();
    setState(() {
      _updatingOrder = id;
      _error = null;
    });
    try {
      await backend.updateOrder(id, status);
      if (!mounted) return;
      final refreshed = await _refresh(refreshCatalog: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(refreshed
            ? (status == 'cancelled'
                ? 'ยกเลิกคำสั่งซื้อและคืนสต็อกแล้ว'
                : 'เปลี่ยนสถานะเป็นจัดสินค้าแล้ว')
            : 'บันทึกสถานะแล้ว แต่โหลดข้อมูลล่าสุดไม่สำเร็จ กรุณารีเฟรช'),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _updatingOrder = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: adminBackground,
        appBar: AppBar(
          backgroundColor: adminBackground,
          title: const Text('จัดการตู้ยา',
              style: TextStyle(color: adminInk, fontWeight: FontWeight.bold)),
          actions: [
            if (backend.isLoggedIn) ...[
              IconButton(
                tooltip: 'รีเฟรชข้อมูล',
                onPressed: _busy ? null : () => _refresh(refreshCatalog: true),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'ออกจากระบบแอดมิน',
                onPressed: _busy ? null : _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: !backend.isLoggedIn ? _loginView() : _dashboard(),
        ),
      );

  Widget _loginView() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AdminSurface(
              child: Form(
                key: _loginForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xffe5f2e9),
                        child: Icon(Icons.admin_panel_settings_outlined,
                            color: adminInk, size: 30),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('PharmaCare+ Admin',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: adminInk)),
                    const SizedBox(height: 8),
                    const Text(
                        'เข้าสู่ระบบเพื่อจัดการสินค้า สต็อก\nและคำสั่งซื้อของตู้ยา',
                        style: TextStyle(color: adminMuted, height: 1.6)),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      AdminMessage(message: _error!),
                      const SizedBox(height: 18),
                    ],
                    TextFormField(
                      key: const Key('admin-username'),
                      controller: _username,
                      enabled: !_loggingIn,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ใช้',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder()),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'กรอกชื่อผู้ใช้'
                              : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('admin-password'),
                      controller: _password,
                      enabled: !_loggingIn,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'แสดงรหัสผ่าน'
                              : 'ซ่อนรหัสผ่าน',
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'กรอกรหัสผ่าน'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('admin-login'),
                      onPressed: _loggingIn ? null : _login,
                      style: FilledButton.styleFrom(backgroundColor: adminInk),
                      icon: _loggingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(_loggingIn
                          ? 'กำลังเข้าสู่ระบบ…'
                          : 'เข้าสู่ระบบแอดมิน'),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                        'บัญชีเดโมอยู่ในไฟล์ backend/data/demo_credentials.txt บนเครื่องที่รันหลังบ้าน',
                        style: TextStyle(
                            color: adminMuted, fontSize: 12, height: 1.6)),
                    const SizedBox(height: 8),
                    Text('เซิร์ฟเวอร์: ${backend.baseUrl}',
                        style:
                            const TextStyle(color: adminMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _dashboard() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ดูแลร้านของคุณ',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: adminInk)),
                const SizedBox(height: 8),
                Text(
                    'ผู้ดูแล ${backend.username ?? ''} • ข้อมูลจากระบบหลังบ้าน',
                    style: const TextStyle(color: adminMuted)),
                const SizedBox(height: 22),
                LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth < 600
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 28) / 3;
                  return Wrap(spacing: 14, runSpacing: 14, children: [
                    SizedBox(
                        width: width,
                        child: _stat(
                            Icons.inventory_2_outlined,
                            'สินค้าทั้งหมด',
                            '${_products.length}',
                            'เปิดขาย ${_products.where((p) => p.active).length} รายการ')),
                    SizedBox(
                        width: width,
                        child: _stat(
                            Icons.warning_amber_rounded,
                            'สินค้าหมด',
                            '${_products.where((p) => p.active && p.stock == 0).length}',
                            'เฉพาะสินค้าที่เปิดขาย')),
                    SizedBox(
                        width: width,
                        child: _stat(
                            Icons.receipt_long_outlined,
                            'รอจัดสินค้า',
                            '${_orders.where((o) => o['status'] == 'pending').length}',
                            'จากคำสั่งซื้อทดลอง')),
                  ]);
                }),
                const SizedBox(height: 24),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  ChoiceChip(
                    label: const Text('สินค้าและสต็อก'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    selected: _tab == 0,
                    onSelected: (_) => setState(() => _tab = 0),
                  ),
                  ChoiceChip(
                    label: const Text('คำสั่งซื้อ'),
                    avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                    selected: _tab == 1,
                    onSelected: (_) => setState(() => _tab = 1),
                  ),
                ]),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  AdminMessage(message: _error!),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _refresh(refreshCatalog: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองโหลดข้อมูลอีกครั้ง'))),
                  const SizedBox(height: 12),
                ],
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                ],
                if (_tab == 0) _productList() else _orderList(),
              ],
            ),
          ),
        ),
      );

  Widget _stat(IconData icon, String label, String value, String detail) =>
      AdminSurface(
        padding: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: adminInk, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: const TextStyle(color: adminMuted)))
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: adminInk)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: adminMuted, fontSize: 12)),
        ]),
      );

  Widget _productList() {
    final search = _query.trim().toLowerCase();
    final products = _products
        .where((p) =>
            p.name.toLowerCase().contains(search) ||
            p.category.contains(search))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            const Text('จัดการสินค้า',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: adminInk)),
            FilledButton.icon(
              key: const Key('admin-add-product'),
              onPressed: _busy ? null : () => _editProduct(),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มสินค้า'),
            ),
          ]),
      const SizedBox(height: 16),
      TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อสินค้าหรือหมวดหมู่',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffdce8df))),
        ),
      ),
      const SizedBox(height: 14),
      if (!_loading && products.isEmpty)
        const AdminSurface(
            child: Text('ไม่พบสินค้า', style: TextStyle(color: adminMuted)))
      else
        for (final product in products) ...[
          _productRow(product),
          const SizedBox(height: 12),
        ],
    ]);
  }

  Widget _productRow(Medicine product) => AdminSurface(
        padding: 16,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 58,
            height: 70,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: adminBackground,
                borderRadius: BorderRadius.circular(10)),
            child: MedicineImage(medicine: product),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: adminInk,
                      fontSize: 16)),
              const SizedBox(height: 6),
              Text(product.category,
                  style: const TextStyle(color: adminMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(baht((product.price * 100).round()),
                        style: const TextStyle(
                            color: adminInk, fontWeight: FontWeight.w700)),
                    AdminTag(
                        label: 'คงเหลือ ${product.stock} ชิ้น',
                        color: product.stock == 0
                            ? const Color(0xffaa4e1c)
                            : adminInk,
                        background: product.stock == 0
                            ? const Color(0xfffff0e2)
                            : const Color(0xffeaf5ee)),
                    if (!product.active)
                      const AdminTag(
                          label: 'ปิดขาย',
                          color: Color(0xff62716a),
                          background: Color(0xffeef0ef)),
                  ]),
            ]),
          ),
          IconButton(
            tooltip: 'แก้ไข ${product.name}',
            onPressed: _busy ? null : () => _editProduct(product),
            icon: const Icon(Icons.edit_outlined, color: adminInk),
          ),
        ]),
      );

  Widget _orderList() {
    final orders = _orders
        .where(
            (order) => _orderFilter == 'all' || order['status'] == _orderFilter)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('คำสั่งซื้อ',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: adminInk)),
      const SizedBox(height: 6),
      const Text('คำสั่งซื้อทั้งหมดเป็นการทดลอง ไม่มีการรับเงินจริง',
          style: TextStyle(color: adminMuted)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final status in ['all', 'pending', 'fulfilled', 'cancelled'])
          FilterChip(
              label: Text(status == 'all' ? 'ทั้งหมด' : _statusLabel(status)),
              selected: _orderFilter == status,
              onSelected: (_) => setState(() => _orderFilter = status)),
      ]),
      const SizedBox(height: 16),
      if (!_loading && orders.isEmpty)
        const AdminSurface(
            child: Text('ยังไม่มีคำสั่งซื้อในสถานะนี้',
                style: TextStyle(color: adminMuted)))
      else
        for (final order in orders) ...[
          _orderCard(order),
          const SizedBox(height: 14),
        ],
    ]);
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = order['id'].toString();
    final status = order['status'].toString();
    final items = (order['items'] as List? ?? []).whereType<Map>();
    return AdminSurface(
      padding: 4,
      child: ExpansionTile(
        key: PageStorageKey('admin-order-$id'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        title: Text('คำสั่งซื้อ #${id.length > 12 ? id.substring(0, 12) : id}',
            style:
                const TextStyle(fontWeight: FontWeight.w700, color: adminInk)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_date(order['created_at']),
                style: const TextStyle(color: adminMuted, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusTag(status),
                  const AdminTag(
                      label: 'ทดลอง',
                      color: adminMuted,
                      background: Color(0xfff1f4f2)),
                  Text(baht(_money(order, 'total_satang')),
                      style: const TextStyle(
                          color: adminInk, fontWeight: FontWeight.w700)),
                ]),
          ]),
        ),
        children: [
          const Divider(color: Color(0xffdce8df)),
          Align(
              alignment: Alignment.centerLeft,
              child: SelectableText('รหัส: $id',
                  key: PageStorageKey('admin-order-id-$id'),
                  style: const TextStyle(fontSize: 12, color: adminMuted))),
          const SizedBox(height: 18),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text('${item['name']} × ${item['quantity']}',
                        style: const TextStyle(color: adminInk))),
                const SizedBox(width: 12),
                Text(baht(_money(item, 'total_satang')),
                    style: const TextStyle(
                        color: adminInk, fontWeight: FontWeight.w600)),
              ]),
            ),
          const Divider(color: Color(0xffdce8df)),
          _orderAmount('ยอดสินค้า', baht(_money(order, 'subtotal_satang'))),
          _orderAmount(
              'ส่วนลด${order['coupon'] == null ? '' : ' (${order['coupon']})'}',
              '-${baht(_money(order, 'discount_satang'))}'),
          _orderAmount('ยอดชำระ', baht(_money(order, 'total_satang'))),
          _orderAmount('วิธีชำระ',
              order['payment_method'] == 'cash' ? 'เงินสดจำลอง' : 'QR ทดลอง'),
          if (order['payment_method'] == 'cash') ...[
            _orderAmount('รับเงินจำลอง', baht(_money(order, 'paid_satang'))),
            _orderAmount('เงินทอน', baht(_money(order, 'change_satang'))),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('เปลี่ยนสถานะในระบบเดโม ไม่มีการสั่งงานตู้จริง',
                    style: TextStyle(color: adminMuted, fontSize: 12))),
            const SizedBox(height: 12),
            if (_updatingOrder == id) const LinearProgressIndicator(),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _updateOrder(order, 'fulfilled'),
                  icon: const Icon(Icons.check),
                  label: const Text('จัดสินค้าแล้ว')),
              OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _updateOrder(order, 'cancelled'),
                  icon: const Icon(Icons.close),
                  label: const Text('ยกเลิกและคืนสต็อก')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _orderAmount(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(label, style: const TextStyle(color: adminMuted)),
              Text(value,
                  style: const TextStyle(
                      color: adminInk, fontWeight: FontWeight.w600)),
            ]),
      );

  int _money(Map order, String key) => (order[key] as num? ?? 0).toInt();

  String _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return value?.toString() ?? '';
    String pad(int number) => number.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year + 543} • ${pad(date.hour)}:${pad(date.minute)}';
  }

  String _statusLabel(String status) => switch (status) {
        'pending' => 'รอจัดสินค้า',
        'fulfilled' => 'จัดสินค้าแล้ว',
        'cancelled' => 'ยกเลิกแล้ว',
        _ => status,
      };

  Widget _statusTag(String status) => AdminTag(
        label: _statusLabel(status),
        color: status == 'pending'
            ? const Color(0xff946316)
            : status == 'cancelled'
                ? const Color(0xff9a4c3b)
                : adminInk,
        background: status == 'pending'
            ? const Color(0xfffff4dc)
            : status == 'cancelled'
                ? const Color(0xffffede8)
                : const Color(0xffeaf5ee),
      );
}
