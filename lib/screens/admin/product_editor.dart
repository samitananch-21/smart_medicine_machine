import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/medicine.dart';
import '../../services/backend_client.dart';
import 'admin_widgets.dart';

const _categories = [
  'ยาและบรรเทาอาการ',
  'ทำแผลและปฐมพยาบาล',
  'วิตามินและสุขภาพ',
  'ของใช้ส่วนตัว',
  'เครื่องดื่ม',
];

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, this.medicine});

  final Medicine? medicine;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _detail;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _warning;
  late String _category;
  String? _image;
  List<String> _images = [];
  bool _loadingImages = true;
  bool _active = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.medicine;
    _name = TextEditingController(text: product?.name ?? '');
    _detail = TextEditingController(text: product?.detail ?? '');
    _price =
        TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _warning = TextEditingController(text: product?.warning ?? '');
    _category = product?.category ?? _categories.first;
    _image = product?.image;
    _active = product?.active ?? true;
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final images = manifest.listAssets().where((path) {
        final lower = path.toLowerCase();
        return path.startsWith('assets/images/') &&
            ['.png', '.jpg', '.jpeg', '.webp'].any(lower.endsWith);
      }).toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _images = images;
        if (!_images.contains(_image)) _image = null;
        _loadingImages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingImages = false;
        _error = 'โหลดรายการรูปภาพไม่สำเร็จ กรุณาปิดหน้านี้แล้วลองอีกครั้ง';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _price.dispose();
    _stock.dispose();
    _warning.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final warning = _warning.text.trim();
    try {
      await backend.saveProduct({
        'name': _name.text.trim(),
        'detail': _detail.text.trim(),
        'price_satang': (double.parse(_price.text.trim()) * 100).round(),
        'stock': int.parse(_stock.text.trim()),
        'image': _image!,
        'category': _category,
        'warning': warning.isEmpty ? null : warning,
        'active': _active,
        if (widget.medicine != null) 'version': widget.medicine!.version,
      }, id: widget.medicine?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      if (!backend.isLoggedIn) {
        Navigator.pop(context, false);
        return;
      }
      setState(() {
        _saving = false;
        _error = error is BackendException
            ? error.message
            : 'บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            widget.medicine == null
                                ? 'เพิ่มสินค้า'
                                : 'แก้ไขสินค้า',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: adminInk)),
                        const SizedBox(height: 6),
                        const Text('ราคาและสต็อกที่บันทึกจะใช้กับหน้าร้าน',
                            style: TextStyle(color: adminMuted)),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          AdminMessage(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        TextFormField(
                          key: const Key('admin-product-name'),
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 160,
                          decoration: const InputDecoration(
                              labelText: 'ชื่อสินค้า',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'กรอกชื่อสินค้า'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _detail,
                          enabled: !_saving,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                              labelText: 'รายละเอียดสินค้า',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'กรอกรายละเอียดสินค้า'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(builder: (context, constraints) {
                          final fields = [
                            TextFormField(
                              key: const Key('admin-product-price'),
                              controller: _price,
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'ราคา (บาท)',
                                  border: OutlineInputBorder()),
                              validator: (value) {
                                final price =
                                    double.tryParse(value?.trim() ?? '');
                                if (price == null ||
                                    !price.isFinite ||
                                    price <= 0) {
                                  return 'กรอกราคามากกว่า 0';
                                }
                                if (price > 1000000) {
                                  return 'ราคาไม่เกิน 1,000,000 บาท';
                                }
                                if (!RegExp(r'^\d+(\.\d{1,2})?$')
                                    .hasMatch(value!.trim())) {
                                  return 'ใช้ทศนิยมไม่เกิน 2 ตำแหน่ง';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              key: const Key('admin-product-stock'),
                              controller: _stock,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'สต็อก (ชิ้น)',
                                  border: OutlineInputBorder()),
                              validator: (value) {
                                final stock = int.tryParse(value?.trim() ?? '');
                                if (stock == null || stock < 0) {
                                  return 'กรอกจำนวนตั้งแต่ 0 ขึ้นไป';
                                }
                                return stock > 100000
                                    ? 'สต็อกไม่เกิน 100,000 ชิ้น'
                                    : null;
                              },
                            ),
                          ];
                          if (constraints.maxWidth < 400) {
                            return Column(children: [
                              fields[0],
                              const SizedBox(height: 18),
                              fields[1]
                            ]);
                          }
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 16),
                                Expanded(child: fields[1]),
                              ]);
                        }),
                        const SizedBox(height: 22),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'หมวดหมู่',
                              border: OutlineInputBorder()),
                          items: {..._categories, _category}
                              .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _category = value!),
                        ),
                        const SizedBox(height: 22),
                        if (_loadingImages)
                          const LinearProgressIndicator()
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey('admin-image-$_image'),
                            initialValue: _image,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'รูปสินค้าที่มีในแอป',
                                border: OutlineInputBorder()),
                            items: _images
                                .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.split('/').last,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _image = value),
                            validator: (value) => value == null || value.isEmpty
                                ? 'เลือกรูปสินค้า'
                                : null,
                          ),
                        if (_image != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            height: 100,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: adminBackground,
                                borderRadius: BorderRadius.circular(12)),
                            child: Image.asset(_image!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, error, stack) => const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: adminMuted)),
                          ),
                        ],
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _warning,
                          enabled: !_saving,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                              labelText: 'คำเตือน (ถ้ามี)',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('เปิดขายสินค้า'),
                          subtitle: const Text(
                              'ปิดเพื่อซ่อนจากหน้าร้าน โดยเก็บประวัติคำสั่งซื้อไว้'),
                          value: _active,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _active = value),
                        ),
                      ],
                    ),
                  ),
                )),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('ยกเลิก'),
                      ),
                      FilledButton.icon(
                        key: const Key('admin-product-save'),
                        onPressed: _saving || _loadingImages ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'กำลังบันทึก…' : 'บันทึกสินค้า'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
