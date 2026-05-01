import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final String pdfUrl;

  const InvoicePreviewScreen({super.key, required this.pdfUrl});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

  @override
class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice Preview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load PDF:\n$errorMessage\n\nURL: ${widget.pdfUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
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
