import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  group('OrderModel.fromJson null-safety tests', () {
    test('parses full valid JSON correctly', () {
      final json = {
        'id': 'ord-123',
        'part_code': 'P-001',
        'part_name': 'Motor Assembly',
        'quantity': 2,
        'price': 1500.50,
        'gst': 270.09,
        'total_amount': 3271.09,
        'status': 'Completed',
        'created_at': '2026-10-07T10:00:00Z',
      };

      final order = OrderModel.fromJson(json);
      expect(order.id, 'ord-123');
      expect(order.partCode, 'P-001');
      expect(order.partName, 'Motor Assembly');
      expect(order.quantity, 2);
      expect(order.price, 1500.50);
      expect(order.gst, 270.09);
      expect(order.totalAmount, 3271.09);
      expect(order.status, 'Completed');
      expect(order.createdAt.isUtc, isTrue);
    });

    test('handles null and missing fields gracefully without crashing', () {
      final json = <String, dynamic>{};

      final order = OrderModel.fromJson(json);
      expect(order.id, '');
      expect(order.partCode, '');
      expect(order.partName, '');
      expect(order.quantity, 0);
      expect(order.price, 0.0);
      expect(order.gst, 0.0);
      expect(order.totalAmount, 0.0);
      expect(order.status, 'Pending');
      expect(order.createdAt, isA<DateTime>());
    });

    test('coerces string numbers and non-string IDs', () {
      final json = {
        'id': 9999,
        'part_code': 42,
        'part_name': 'Sensor Cable',
        'quantity': '5',
        'price': '250.75',
        'gst': '45.13',
        'total_amount': '1298.88',
        'status': null,
        'created_at': 'invalid-date',
      };

      final order = OrderModel.fromJson(json);
      expect(order.id, '9999');
      expect(order.partCode, '42');
      expect(order.quantity, 5);
      expect(order.price, 250.75);
      expect(order.gst, 45.13);
      expect(order.totalAmount, 1298.88);
      expect(order.status, 'Pending');
    });
  });

  group('SparePart.fromJson null-safety tests', () {
    test('parses complete spare part row correctly', () {
      final json = {
        'id': 101,
        'part_name': 'BLDC Motor 1200mm',
        'part_code': 'MTR-1200',
        'model': 'Renesa+',
        'price': 1850.0,
        'stock_quantity': 15,
        'status': 'Available',
      };

      final part = SparePart.fromJson(json);
      expect(part.id, '101');
      expect(part.partName, 'BLDC Motor 1200mm');
      expect(part.partCode, 'MTR-1200');
      expect(part.model, 'Renesa+');
      expect(part.price, 1850.0);
      expect(part.stockQuantity, 15);
      expect(part.status, 'Available');
    });

    test('handles empty or missing fields with safe defaults', () {
      final json = <String, dynamic>{};

      final part = SparePart.fromJson(json);
      expect(part.id, '');
      expect(part.partName, '');
      expect(part.partCode, '');
      expect(part.model, 'N/A');
      expect(part.price, 0.0);
      expect(part.stockQuantity, 0);
      expect(part.status, 'Out of Stock');
    });
  });
}
