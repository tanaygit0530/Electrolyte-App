import 'dart:async';
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

class _SerialCheckScreenState extends State<SerialCheckScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  late final MobileScannerController _scannerController;

  bool _isTorchOn = false;
  bool _isProcessingScan = false;
  bool _hasDetectionTimedOut = false;
  Timer? _noBarcodeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: false,
    );
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Initialize camera and start 15s detection timer for Live Scan tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabController.index == 0) {
        _startLiveScan();
      }
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      final provider = context.read<SerialCheckProvider>();
      if (provider.result == null) {
        _startLiveScan();
      }
    } else {
      _stopLiveScan();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopLiveScan();
    } else if (state == AppLifecycleState.resumed) {
      if (_tabController.index == 0 && mounted) {
        final provider = context.read<SerialCheckProvider>();
        if (provider.result == null &&
            !_hasDetectionTimedOut &&
            !_isProcessingScan) {
          _startLiveScan();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelDetectionTimer();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _textController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Start camera stream and 15-second barcode detection countdown
  void _startLiveScan() async {
    _cancelDetectionTimer();
    if (mounted) {
      setState(() {
        _hasDetectionTimedOut = false;
        _isProcessingScan = false;
      });
    }

    _startDetectionTimer();

    try {
      if (!_scannerController.value.isRunning) {
        await _scannerController.start();
      }
    } catch (e) {
      debugPrint('[SerialCheckScreen] Error starting camera: $e');
    }
  }

  /// Stop camera stream and cancel any pending detection timers
  void _stopLiveScan() {
    _cancelDetectionTimer();
    try {
      if (_scannerController.value.isRunning) {
        _scannerController.stop();
      }
    } catch (_) {}
  }

  /// 15-second detection window timer
  void _startDetectionTimer() {
    _cancelDetectionTimer();
    _noBarcodeTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_tabController.index == 0 && !_isProcessingScan) {
        final provider = context.read<SerialCheckProvider>();
        if (provider.result == null && !provider.isLoading) {
          setState(() {
            _hasDetectionTimedOut = true;
          });
          // Pause camera when 15 seconds expire without a detection
          _scannerController.stop();
        }
      }
    });
  }

  void _cancelDetectionTimer() {
    _noBarcodeTimer?.cancel();
    _noBarcodeTimer = null;
  }

  /// Handles barcode detection from camera stream
  void _onBarcodeScanned(BarcodeCapture capture) async {
    if (_isProcessingScan || _hasDetectionTimedOut) return;

    final provider = context.read<SerialCheckProvider>();
    if (provider.isLoading || provider.result != null) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _cancelDetectionTimer();
    setState(() {
      _isProcessingScan = true;
    });

    // Pause camera during database verification to prevent overlapping scans
    try {
      await _scannerController.stop();
    } catch (_) {}

    await provider.checkSerial(rawValue);

    if (mounted) {
      setState(() {
        _isProcessingScan = false;
      });
    }
  }

  /// Reset provider and restart scanner without requiring app restart
  void _resetAll() {
    final provider = context.read<SerialCheckProvider>();
    provider.reset();
    _textController.clear();
    if (_tabController.index == 0) {
      _startLiveScan();
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
            onPressed: _resetAll,
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
                  Tab(
                    icon: Icon(Icons.photo_library_outlined),
                    text: 'Upload Image',
                  ),
                  Tab(
                    icon: Icon(Icons.edit_note_outlined),
                    text: 'Manual Entry',
                  ),
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
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.primaryYellow,
                          ),
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
  Widget _buildCameraScannerTab(
    BuildContext context,
    SerialCheckProvider provider,
    bool isDark,
  ) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeScanned,
          errorBuilder: (context, error, child) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Color(0xFFEF4444),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Camera Unavailable',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.errorDetails?.message ??
                          'Camera permission was denied or camera is unavailable. Please grant permission or use manual entry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            _tabController.animateTo(2);
                          },
                          child: const Text('Manual Entry'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _startLiveScan,
                          child: const Text('Retry Camera'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryYellow,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Point camera at the QR code or Barcode sticker on the product',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Friendly 15-second Detection Timeout Overlay
        if (_hasDetectionTimedOut && provider.errorMessage == null && !provider.isLoading)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      color: AppTheme.primaryYellow,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Barcode Detected',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No barcode detected. Adjust the camera or try manual entry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _cancelDetectionTimer();
                            setState(() {
                              _hasDetectionTimedOut = false;
                            });
                            _tabController.animateTo(2);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Manual Entry'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startLiveScan,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry Scan'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Friendly Error Banner with Retry & Manual Entry actions
        if (provider.errorMessage != null && !provider.isLoading)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verification Issue',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              provider.errorMessage!,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            provider.clearError();
                            _startLiveScan();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Scan Again', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            provider.clearError();
                            _tabController.animateTo(2);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Manual Entry', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (provider.currentSerial != null &&
                                provider.currentSerial!.isNotEmpty) {
                              await provider.retry();
                            } else {
                              provider.clearError();
                              _startLiveScan();
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- TAB 2: Upload Image from Gallery ---
  Widget _buildUploadImageTab(
    BuildContext context,
    SerialCheckProvider provider,
    bool isDark,
  ) {
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 64,
                  color: isDark
                      ? AppTheme.primaryYellow
                      : Colors.amber.shade800,
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
                  onPressed: () =>
                      provider.pickAndScanImage(_scannerController),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Select from Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.retry(),
                    child: const Text('Retry'),
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
  Widget _buildManualEntryTab(
    BuildContext context,
    SerialCheckProvider provider,
    bool isDark,
  ) {
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
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
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryYellow,
                        width: 2,
                      ),
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
                        : () =>
                              provider.checkSerial(_textController.text.trim()),
                    icon: const Icon(Icons.search),
                    label: const Text('Check 60-Day Status'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- RESULT VIEW: REPEAT RISK (RED) vs REVIEW NEEDED (AMBER) vs SAFE TO CLOSE (GREEN) ---
  Widget _buildResultView(
    BuildContext context,
    SerialCheckProvider provider,
    bool isDark,
  ) {
    final result = provider.result!;
    final isRepeatRisk = result.isRepeatRisk;
    final isReviewNeeded = result.isReviewNeeded;

    // Strict 3-state styling: Red for repeat risk, Amber for review required, Green for safe to close
    final Color primaryColor = isRepeatRisk
        ? const Color(0xFFEF4444)
        : (isReviewNeeded
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981));

    final IconData statusIcon = isRepeatRisk
        ? Icons.warning_amber_rounded
        : (isReviewNeeded
            ? Icons.error_outline_rounded
            : Icons.check_circle_rounded);

    final String statusLabel = isRepeatRisk
        ? 'REPEAT RISK (≤ 60 DAYS)'
        : (isReviewNeeded
            ? 'REVIEW NEEDED'
            : 'SAFE TO CLOSE (> 60 DAYS)');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with prominent REPEAT RISK / REVIEW / SAFE TO CLOSE status
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.16),
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
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: primaryColor,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 16),

                // Status Text Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Human-readable message from backend
                if (result.message != null && result.message!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6, bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      result.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                      ),
                    ),
                  ),

                const Divider(),
                const SizedBox(height: 10),

                // Days Ago & Last Service Date Pills
                if (result.daysAgo != null || result.lastServiceDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (result.daysAgo != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_toggle_off, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${result.daysAgo} days ago',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        if (result.lastServiceDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Last: ${result.lastServiceDate}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // Serial Number badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Serial No: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
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
                  _buildDetailRow(
                    'Product',
                    result.record?['productName'] ?? 'N/A',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Product Code',
                    result.record?['productCode'] ?? 'N/A',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Case Number',
                    result.record?['caseNumber'] ?? 'N/A',
                    isDark,
                  ),
                  _buildDetailRow(
                    'End Date',
                    result.record?['endDate'] ??
                        result.record?['serviceDate'] ??
                        'N/A',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Customer',
                    result.record?['customerName'] ?? 'N/A',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Location',
                    '${result.record?['city'] ?? ''} ${result.record?['state'] ?? ''}'
                        .trim(),
                    isDark,
                  ),
                  _buildDetailRow(
                    'Complaint',
                    result.record?['complaint'] ?? 'None recorded',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Repair / Action',
                    result.record?['repair'] ?? 'None recorded',
                    isDark,
                  ),
                  _buildDetailRow(
                    'Status',
                    result.record?['status'] ?? 'N/A',
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _resetAll,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Verify Another Serial Number',
                style: TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65);
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
    canvas.drawLine(
      scanRect.topLeft,
      scanRect.topLeft + const Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      scanRect.topLeft,
      scanRect.topLeft + const Offset(0, cornerLength),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      scanRect.topRight,
      scanRect.topRight + const Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      scanRect.topRight,
      scanRect.topRight + const Offset(0, cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      scanRect.bottomLeft,
      scanRect.bottomLeft + const Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      scanRect.bottomLeft,
      scanRect.bottomLeft + const Offset(0, -cornerLength),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      scanRect.bottomRight,
      scanRect.bottomRight + const Offset(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      scanRect.bottomRight,
      scanRect.bottomRight + const Offset(0, -cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
