class Medicine {
  final String id;
  final String name;
  final String detail;
  final double price;
  final String image;
  final String? warning;
  final String category;
  final int stock;
  final bool active;
  final int version;

  Medicine({
    this.id = '',
    required this.name,
    required this.detail,
    required this.price,
    required this.image,
    this.warning,
    this.category = 'ยาและบรรเทาอาการ',
    this.stock = 20,
    this.active = true,
    this.version = 1,
  });

  int get priceSatang => (price * 100).round();
  String get cartKey => id.isEmpty ? name : id;

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        detail: json['detail'] as String,
        price: (json['price_satang'] as int) / 100,
        image: json['image'] as String,
        warning: json['warning'] as String?,
        category: json['category'] as String,
        stock: json['stock'] as int,
        active: json['active'] as bool,
        version: json['version'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'detail': detail,
        'price_satang': priceSatang,
        'image': image,
        'warning': warning,
        'category': category,
        'stock': stock,
        'active': active,
        'version': version,
      };
}
