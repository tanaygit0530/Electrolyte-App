import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/chat_history_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/invoice_provider.dart';
import 'invoice_preview_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
      context.read<ChatHistoryProvider>().fetchSessions();
      context.read<InvoiceProvider>().fetchInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'History',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Orders"),
              Tab(text: "Chats"),
              Tab(text: "Invoices"),
            ],
            indicatorColor: Color(0xFFFFC107),
            labelColor: Color(0xFFFFC107),
            unselectedLabelColor: Colors.grey,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<OrderProvider>().fetchOrders();
                context.read<ChatHistoryProvider>().fetchSessions();
                context.read<InvoiceProvider>().fetchInvoices();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOrderHistory(),
            _buildChatHistory(),
            _buildInvoiceHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.orders.isEmpty) {
          return const Center(child: Text("No order history found."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.orders.length,
          itemBuilder: (context, index) {
            final order = provider.orders[index];
            return _HistoryCard(
              title: order.partName,
              subtitle: "Order ID: ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}...",
              date: DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
              status: order.status,
              icon: Icons.shopping_bag_outlined,
              onTap: () {},
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistory() {
    return Consumer<ChatHistoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.sessions.isEmpty) {
          return const Center(child: Text("No chat history found."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.sessions.length,
          itemBuilder: (context, index) {
            final session = provider.sessions[index];
            return _HistoryCard(
              title: session.title,
              subtitle: "Chat Session",
              date: DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(session.updatedAt),
              status: "View Chat",
              icon: Icons.chat_outlined,
              onTap: () async {
                final chatProvider = context.read<ChatProvider>();
                final navProvider = context.read<NavigationProvider>();
                await chatProvider.loadSession(session.id);
                navProvider.setIndex(0);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInvoiceHistory() {
    return Consumer<InvoiceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.invoices.isEmpty) {
          return const Center(child: Text("No invoice history found."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.invoices.length,
          itemBuilder: (context, index) {
            final invoice = provider.invoices[index];
            return _HistoryCard(
              title: invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : "Invoice #${invoice.id}",
              subtitle: "Customer: ${invoice.customerName}\nPrepared by: ${invoice.preparedBy ?? 'N/A'}",
              date: DateFormat('dd MMM yyyy, hh:mm a').format(invoice.createdAt),
              status: "₹${invoice.totalAmount.toStringAsFixed(2)}",
              icon: Icons.receipt_long_outlined,
              onTap: () {
                if (invoice.pdfUrl != null && invoice.pdfUrl!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoicePreviewScreen(pdfUrl: invoice.pdfUrl!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF preview is not available yet. Cloudinary upload might be in progress.'),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String status;
  final IconData icon;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFC107),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 4),
            Text(
              "Date: $date",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Text(
          status,
          style: const TextStyle(
            color: Color(0xFFFFC107),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
