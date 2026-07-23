import 'package:flutter/foundation.dart';

final class Product {
  const Product({required this.id, required this.name});

  final int id;
  final String name;
}

final class CatalogController extends ChangeNotifier {
  final List<Product> products = List.generate(
    12,
    (index) => Product(id: index, name: '商品 ${index + 1}'),
  );

  void appendProducts() {
    final start = products.length;
    products.addAll(
      List.generate(
        5,
        (index) =>
            Product(id: start + index, name: '追加商品 ${start + index + 1}'),
      ),
    );
    notifyListeners();
  }
}
