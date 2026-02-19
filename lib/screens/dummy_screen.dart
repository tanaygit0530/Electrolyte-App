import 'package:flutter/material.dart';

class DummyScreen extends StatelessWidget {
  const DummyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛠 Upcoming Features')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _DummyCard(
            title: "Warehouse Tracking",
            icon: Icons.warehouse,
            description:
                "Real-time tracking of warehouse inventory and shipments.",
          ),
          _DummyCard(
            title: "Service History",
            icon: Icons.history,
            description:
                "View complete maintenance and repair history of all parts.",
          ),
          _DummyCard(
            title: "Analytics Dashboard",
            icon: Icons.analytics,
            description:
                "Visual insights into stock usage and demand forecasting.",
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              "Coming Soon",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DummyCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const _DummyCard({
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.lock_outline, size: 16),
      ),
    );
  }
}
