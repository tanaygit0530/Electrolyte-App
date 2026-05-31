import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../utils/theme.dart';

class AdminInvoicePreviewScreen extends StatefulWidget {
  final String pdfUrl;

  const AdminInvoicePreviewScreen({super.key, required this.pdfUrl});

  @override
  State<AdminInvoicePreviewScreen> createState() => _AdminInvoicePreviewScreenState();
}

class _AdminInvoicePreviewScreenState extends State<AdminInvoicePreviewScreen> {
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Invoice Preview Document',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins'),
        ),
        backgroundColor: AdminTheme.sidebarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AdminTheme.primaryYellow, size: 20),
            tooltip: 'Share Bill',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sharing compiled PDF invoices coming soon!', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
                  backgroundColor: AdminTheme.primaryYellow,
                  behavior: SnackBarBehavior.floating,
                  width: 340,
                ),
              );
            },
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.glassBox(radius: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AdminTheme.errorColor, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load compiled PDF document:\n$errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AdminTheme.errorColor, fontFamily: 'Poppins', fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Compiled URL: ${widget.pdfUrl}',
                        style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.6), fontSize: 12, fontFamily: 'Poppins'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SfPdfViewer.network(
              widget.pdfUrl,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                if (mounted) {
                  setState(() {
                    errorMessage = details.error;
                  });
                }
              },
            ),
    );
  }
}
