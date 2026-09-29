import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

class BackendException implements Exception {
  final String message;
  final int? status;
  const BackendException(this.message, [this.status]);
  @override
  String toString() => message;
}

class BackendClient {
  final String baseUrl;
  final http.Client _client;
  // main enables the API; widget/unit tests can inject a client without network.
  bool enabled = false;
  String? _token;
  String? username;
  bool get isLoggedIn => _token != null;

  BackendClient({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ??
                const String.fromEnvironment('API_URL',
                    defaultValue: 'http://127.0.0.1:8765'))
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data, bool auth = false}) async {
    if (auth && _token == null) {
      throw const BackendException('กรุณาเข้าสู่ระบบแอดมิน', 401);
    }
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/api$path'));
      request.headers['Content-Type'] = 'application/json';
      if (auth) request.headers['Authorization'] = 'Bearer $_token';
      if (data != null) request.body = jsonEncode(data);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && auth) {
          _token = null;
          username = null;
        }
        throw BackendException(
            decoded['error'] as String? ?? 'ไม่สามารถทำรายการได้',
            response.statusCode);
      }
      return decoded;
    } on BackendException {
      rethrow;
    } on TimeoutException {
      throw const BackendException(
          'การเชื่อมต่อหมดเวลา ลองส่งอีกครั้งโดยใช้รายการเดิม');
    } on http.ClientException {
      throw const BackendException(
          'เชื่อมต่อหลังบ้านไม่ได้ กรุณาตรวจว่าเปิดเซิร์ฟเวอร์และเชื่อมเครือข่ายเดียวกัน');
    } on FormatException {
      throw const BackendException('ข้อมูลตอบกลับจากหลังบ้านไม่ถูกต้อง');
    }
  }

  Future<List<Medicine>> fetchProducts() async =>
      ((await _request('GET', '/products'))['products'] as List)
          .map((p) => Medicine.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
  Future<void> login(String name, String password) async {
    final result = await _request('POST', '/admin/login',
        data: {'username': name.trim(), 'password': password});
    _token = result['token'] as String;
    username = result['username'] as String;
  }

  Future<void> logout() async {
    try {
      if (_token != null) await _request('POST', '/admin/logout', auth: true);
    } finally {
      _token = null;
      username = null;
    }
  }

  Future<List<Medicine>> fetchAdminProducts() async =>
      ((await _request('GET', '/admin/products', auth: true))['products']
              as List)
          .map((p) => Medicine.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
  Future<Medicine> saveProduct(Map<String, dynamic> data, {String? id}) async {
    final result = await _request(
        id == null ? 'POST' : 'PUT',
        id == null
            ? '/admin/products'
            : '/admin/products/${Uri.encodeComponent(id)}',
        data: data,
        auth: true);
    return Medicine.fromJson(
        Map<String, dynamic>.from(result['product'] as Map));
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async =>
      ((await _request('GET', '/admin/orders', auth: true))['orders'] as List)
          .map((o) => Map<String, dynamic>.from(o as Map))
          .toList();
  Future<void> updateOrder(String id, String status) async {
    await _request('PATCH', '/admin/orders/${Uri.encodeComponent(id)}',
        data: {'status': status}, auth: true);
  }

  Future<Map<String, dynamic>> submitOrder(
          Map<String, dynamic> payload) async =>
      Map<String, dynamic>.from(
          (await _request('POST', '/orders', data: payload))['order'] as Map);
  void close() => _client.close();
}

BackendClient backend = BackendClient();
String newRequestId() => List.generate(24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();
