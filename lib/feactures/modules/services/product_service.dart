import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Modelo ───────────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String userId;
  final String description;
  final double price;
  final String? imageUrl;
  final String? imagePublicId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.userId,
    required this.description,
    required this.price,
    this.imageUrl,
    this.imagePublicId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        userId: json['userId'] as String,
        description: json['description'] as String,
        price: double.parse(json['price'].toString()),
        imageUrl: json['imageUrl'] as String?,
        imagePublicId: json['imagePublicId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

// ─── SaleItem model (snapshot) ────────────────────────────────────────────────

class SaleItemSnapshot {
  final String id;
  final String saleId;
  final String? productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final DateTime createdAt;

  const SaleItemSnapshot({
    required this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    required this.createdAt,
  });

  factory SaleItemSnapshot.fromJson(Map<String, dynamic> json) =>
      SaleItemSnapshot(
        id: json['id'] as String,
        saleId: json['saleId'] as String,
        productId: json['productId'] as String?,
        productName: json['productName'] as String,
        unitPrice: double.parse(json['unitPrice'].toString()),
        quantity: json['quantity'] as int,
        subtotal: double.parse(json['subtotal'].toString()),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ProductService {
  static final String _base = '${dotenv.env['API_BASE_URL']}/modules';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Listar productos ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listProducts({
    required String token,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final uri =
        Uri.parse('$_base/catalog/products').replace(queryParameters: params);

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error al cargar productos');
  }

  // ── Obtener un producto ───────────────────────────────────────────────────

  static Future<Product> getProduct({
    required String token,
    required String id,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/catalog/products/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Product.fromJson(body['product'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cargar el producto');
  }

  // ── Crear producto ────────────────────────────────────────────────────────

  static Future<Product> createProduct({
    required String token,
    required String description,
    required double price,
    String? imageBase64,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/catalog/products'),
          headers: _headers(token),
          body: jsonEncode({
            'description': description,
            'price': price,
            if (imageBase64 != null) 'imageBase64': imageBase64,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return Product.fromJson(body['product'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al crear el producto');
  }

  // ── Editar producto ───────────────────────────────────────────────────────

  static Future<Product> updateProduct({
    required String token,
    required String id,
    String? description,
    double? price,
    String? imageBase64,
    bool removeImage = false,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/catalog/products/$id'),
          headers: _headers(token),
          body: jsonEncode({
            if (description != null) 'description': description,
            if (price != null) 'price': price,
            if (imageBase64 != null) 'imageBase64': imageBase64,
            if (removeImage) 'removeImage': true,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Product.fromJson(body['product'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al actualizar el producto');
  }

  // ── Eliminar producto ─────────────────────────────────────────────────────

  static Future<void> deleteProduct({
    required String token,
    required String id,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/catalog/products/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Error al eliminar el producto');
    }
  }
}
