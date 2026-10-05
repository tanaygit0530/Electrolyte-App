import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/serial_check_provider.dart';

class SerialCheckScreen extends StatefulWidget {
  const SerialCheckScreen({super.key});

  @override
  State<SerialCheckScreen> createState() => _SerialCheckScreenState();
}

class _SerialCheckScreenState extends State<SerialCheckScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeScanned(BarcodeCapture capture) {
    final provider = context.read<SerialCheckProvider>();
    if (provider.isLoading || provider.result != null) return;

    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        provider.checkSerial(rawValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SerialCheckProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, size: 24),
            SizedBox(width: 10),
            Text(
              'Verify Serial Number',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0 && provider.result == null)
            IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Toggle Flash',
              onPressed: () async {
                await _scannerController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: () {
              provider.reset();
              _textController.clear();
            },
          ),
        ],
        bottom: provider.result != null
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: isDark ? AppTheme.primaryYellow : Colors.black,
                labelColor: isDark ? AppTheme.primaryYellow : Colors.black,
                unselectedLabelColor: isDark ? Colors.grey : Colors.black54,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Live Scan'),
                  Tab(icon: Icon(Icons.photo_library_outlined), text: 'Upload Image'),
                  Tab(icon: Icon(Icons.edit_note_outlined), text: 'Manual Entry'),
                ],
              ),
      ),
      body: provider.result != null
          ? _buildResultView(context, provider, isDark)
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCameraScannerTab(context, provider, isDark),
                    _buildUploadImageTab(context, provider, isDark),
                    _buildManualEntryTab(context, provider, isDark),
                  ],
                ),
                if (provider.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryYellow),
                          SizedBox(height: 16),
                          Text(
                            'Verifying Serial in Database...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // --- TAB 1: Live Camera Scanner ---
  Widget _buildCameraScannerTab(BuildContext context, SerialCheckProvider provider, bool isDark) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeScanned,
        ),
        // Darkened overlay with cutout frame
        CustomPaint(
          painter: _ScannerOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        // Top instruction banner
        Positioned(
          top: 24,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryYellow, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Point camera at the QR code or Barcode sticker on the product',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Error banner if any
        if (provider.errorMessage != null)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- TAB 2: Upload Image from Gallery ---
  Widget _buildUploadImageTab(BuildContext context, SerialCheckProvider provider, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 64,
                  color: isDark ? AppTheme.primaryYellow : Colors.amber.shade800,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Upload Sticker Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a photo containing a 1D barcode or QR code sticker (JPEG or PNG).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => provider.pickAndScanImage(_scannerController),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Select from Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          if (provider.selectedImage != null) ...[
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade400),
                image: DecorationImage(
                  image: FileImage(provider.selectedImage!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                border: Border.all(color: const Color(0xFFEF4444)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 3: Manual Text Entry ---
  Widget _buildManualEntryTab(BuildContext context, SerialCheckProvider provider, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.keyboard, color: AppTheme.primaryYellow),
                    SizedBox(width: 10),
                    Text(
                      'Enter Serial Number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'If the barcode is torn or unscannable, enter the printed serial number directly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. LA24AECHA2P13535',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkBlueBg : Colors.white,
                    prefixIcon: const Icon(Icons.qr_code),
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      provider.checkSerial(val);
                    }
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _textController.text.trim().isEmpty
                        ? null
                        : () => provider.checkSerial(_textController.text.trim()),
                    icon: const Icon(Icons.search),
                    label: const Text('Check 60-Day Status'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                border: Border.all(color: const Color(0xFFEF4444)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- RESULT VIEW: REPEAT RISK (RED) vs SAFE TO CLOSE (GREEN) ---
  Widget _buildResultView(BuildContext context, SerialCheckProvider provider, bool isDark) {
    final result = provider.result!;
    final isRepeatRisk = result.isWithin60Days;
    final primaryColor = isRepeatRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final bannerBg = isRepeatRisk
        ? (isDark ? const Color(0xFF3B1212) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF06331E) : const Color(0xFFECFDF5));
    final bannerBorder = isRepeatRisk
        ? const Color(0xFFF87171)
        : const Color(0xFF34D399);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with prominent REPEAT RISK / SAFE TO CLOSE status
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Status Icon with circular glow
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRepeatRisk ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: primaryColor,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 16),

                // Status Text Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isRepeatRisk ? 'REPEAT RISK (< 60 DAYS)' : 'SAFE TO CLOSE (> 60 DAYS)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Prominent Callout Banner with exact user requested messages
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: bannerBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bannerBorder.withOpacity(0.8), width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isRepeatRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        color: primaryColor,
                        size: 30,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isRepeatRisk
                              ? "Don't close the call, it may come in repeat."
                              : "Safe to close the call.",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Subtext / Days Ago detail
                if (isRepeatRisk && result.daysAgo != null)
                  Text(
                    'Last service End Date was ${result.daysAgo} days ago (${result.serviceDate ?? result.record?['endDate'] ?? ''}).\nFalls within the 60-day repeat risk window.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      height: 1.35,
                    ),
                  )
                else if (!isRepeatRisk && result.daysAgo != null)
                  Text(
                    'Last service End Date was ${result.daysAgo} days ago (${result.serviceDate ?? result.record?['endDate'] ?? ''}).\nExceeds 60 days • Safe to close.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    'No prior service records found in database.\nSafe to close.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Serial Number badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Serial No: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    SelectableText(
                      result.serialNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Metadata Card (if record exists)
          if (result.record != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service & Work Order Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Product', result.record?['productName'] ?? 'N/A', isDark),
                  _buildDetailRow('Product Code', result.record?['productCode'] ?? 'N/A', isDark),
                  _buildDetailRow('Case Number', result.record?['caseNumber'] ?? 'N/A', isDark),
                  _buildDetailRow('End Date', result.record?['endDate'] ?? result.record?['serviceDate'] ?? 'N/A', isDark),
                  _buildDetailRow('Customer', result.record?['customerName'] ?? 'N/A', isDark),
                  _buildDetailRow('Location', '${result.record?['city'] ?? ''} ${result.record?['state'] ?? ''}'.trim(), isDark),
                  _buildDetailRow('Complaint', result.record?['complaint'] ?? 'None recorded', isDark),
                  _buildDetailRow('Repair / Action', result.record?['repair'] ?? 'None recorded', isDark),
                  _buildDetailRow('Status', result.record?['status'] ?? 'N/A', isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                provider.reset();
                _textController.clear();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Verify Another Serial Number', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for camera viewfinder cutout frame
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanBoxWidth = size.width * 0.75;
    final double scanBoxHeight = scanBoxWidth;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: scanBoxWidth,
      height: scanBoxHeight,
    );

    // Dim background
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Border corners
    final cornerPaint = Paint()
      ..color = AppTheme.primaryYellow
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-left
    canvas.drawLine(scanRect.topLeft, scanRect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanRect.topLeft, scanRect.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Top-right
    canvas.drawLine(scanRect.topRight, scanRect.topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanRect.topRight, scanRect.topRight + const Offset(0, cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(scanRect.bottomLeft, scanRect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanRect.bottomLeft, scanRect.bottomLeft + const Offset(0, -cornerLength), cornerPaint);

    // Bottom-right
    canvas.drawLine(scanRect.bottomRight, scanRect.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanRect.bottomRight, scanRect.bottomRight + const Offset(0, -cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
