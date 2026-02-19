import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spare_part.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<SparePart>>(
        future: apiService.getAllParts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading alerts"));
          }

          final lowStockParts =
              snapshot.data
                  ?.where(
                    (p) => p.status == 'Low' || p.status == 'Out of Stock',
                  )
                  .toList() ??
              [];

          if (lowStockParts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "All parts are sufficiently stocked.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockParts.length,
            itemBuilder: (context, index) {
              final part = lowStockParts[index];
              final isOutOfStock = part.status == 'Out of Stock';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOutOfStock
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      isOutOfStock
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      color: isOutOfStock ? Colors.red : Colors.orange,
                    ),
                  ),
                  title: Text(
                    "Low Stock: ${part.partName}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Part Code: ${part.partCode}\nCurrent Quantity: ${part.stockQuantity}\nModel: ${part.model}",
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
