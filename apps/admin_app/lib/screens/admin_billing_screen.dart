import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../utils/theme.dart';
import 'admin_invoice_preview_screen.dart';

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = SharedApiService();
  String _warrantyType = 'Out of Warranty (OW)';
  String _brand = 'Select Brand';

  List<SparePart> _searchResults = [];
  final List<SparePart> _selectedParts = [];
  bool _isSearching = false;
  bool _isGenerating = false;
  bool _gstEnabled = false;

  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _preparedByController = TextEditingController(text: 'DIPAK MOHITE');
  final _caseIdController = TextEditingController();
  final _serviceChargeController = TextEditingController(text: '0');

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _serialNumberController.dispose();
    _preparedByController.dispose();
    _caseIdController.dispose();
    _serviceChargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instruction Tagline
              Text(
                'Complete all mandatory invoice fields to securely compile price catalogs and generate PDF bills.',
                style: TextStyle(
                  fontSize: 14,
                  color: AdminTheme.textSecondary.withOpacity(0.8),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 32),

              // Split Layout: 2 Columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Customer & Transaction Details (Card Container)
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: AdminTheme.glassBox(radius: 14, opacity: 0.15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client & Case Metadata',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildDropdownField(
                            "Warranty Designation",
                            _warrantyType,
                            ['Out of Warranty (OW)', 'In Warranty (IW)'],
                            (val) {
                              setState(() => _warrantyType = val!);
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField("Customer Full Name", Icons.person_rounded, "Enter name", controller: _customerNameController, validator: (v) => v!.isEmpty ? 'Customer name is required' : null),
                          const SizedBox(height: 16),

                          _buildTextField("Customer Email Address", Icons.email_rounded, "Enter email", controller: _customerEmailController, validator: (v) => v!.isEmpty ? 'Email is required' : null),
                          const SizedBox(height: 16),

                          _buildDropdownField(
                            "Compatible Brand Selection",
                            _brand,
                            ['Select Brand', 'Atomberg', 'Symphony', 'Bajaj'],
                            (val) {
                              setState(() => _brand = val!);
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField("Product Serial Number", Icons.grid_3x3_rounded, "Enter serial number", controller: _serialNumberController, validator: (v) => v!.isEmpty ? 'Serial number is required' : null),
                          const SizedBox(height: 16),

                          _buildTextField("Technician / Prepared By", Icons.badge_rounded, "Prepared by", controller: _preparedByController, validator: (v) => v!.isEmpty ? 'Prepared by is required' : null),
                          const SizedBox(height: 16),

                          _buildTextField("Support Case ID", Icons.confirmation_number_rounded, "Enter case ID", controller: _caseIdController, validator: (v) => v!.isEmpty ? 'Case ID is required' : null),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // Right Column: Product Selector, Service Charge & Final submission
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        // Card 1: Product Search & Selected list
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: AdminTheme.glassBox(radius: 14, opacity: 0.15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Spare Parts Catalog Search',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 24),

                              _buildSearchField(),
                              
                              if (_isSearching)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator(color: AdminTheme.primaryYellow)),
                                ),

                              if (_searchResults.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.secondaryBg,
                                    border: Border.all(color: AdminTheme.borderColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final part = _searchResults[index];
                                      return ListTile(
                                        title: Text(part.partName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
                                        subtitle: Text("${part.partCode} - ${part.model}", style: const TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins')),
                                        trailing: Text("₹${part.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryYellow, fontFamily: 'Poppins')),
                                        onTap: () {
                                          setState(() {
                                            if (!_selectedParts.any((p) => p.partCode == part.partCode)) {
                                              _selectedParts.add(part);
                                            }
                                            _searchResults = [];
                                            _searchController.clear();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 32),
                              const Text(
                                'Selected Parts List',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: AdminTheme.borderColor),
                              const SizedBox(height: 12),

                              if (_selectedParts.isNotEmpty)
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _selectedParts.length,
                                  itemBuilder: (context, index) {
                                    final part = _selectedParts[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.darkBackground.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AdminTheme.borderColor),
                                      ),
                                      child: ListTile(
                                        title: Text(part.partName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
                                        subtitle: Text("${part.partCode} | Compatibility: ${part.model}", style: const TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins')),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("₹${part.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryYellow, fontFamily: 'Poppins')),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.cancel_rounded, color: AdminTheme.errorColor, size: 20),
                                              onPressed: () => setState(() => _selectedParts.removeAt(index)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                                    child: Text(
                                      'No parts selected. Use search block to add.',
                                      style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.5), fontFamily: 'Poppins', fontSize: 13),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Card 2: Service Charge, GST & Actions
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: AdminTheme.glassBox(radius: 14, opacity: 0.15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Taxes & Service Parameters',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 24),

                              _buildTextField(
                                "Service Charge (INR)",
                                Icons.currency_rupee_rounded,
                                "0",
                                keyboardType: TextInputType.number,
                                controller: _serviceChargeController,
                                validator: (v) => v!.isEmpty ? 'Service charge is required' : null,
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Checkbox(
                                    value: _gstEnabled,
                                    activeColor: AdminTheme.primaryYellow,
                                    checkColor: AdminTheme.darkBackground,
                                    side: const BorderSide(color: AdminTheme.borderColor),
                                    onChanged: (val) {
                                      setState(() => _gstEnabled = val ?? false);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Apply GST (18%)",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 36),

                              // Generate Invoice Button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isGenerating ? null : _generateInvoice,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.primaryYellow,
                                    foregroundColor: AdminTheme.darkBackground,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 8,
                                    shadowColor: AdminTheme.primaryYellow.withOpacity(0.2),
                                  ),
                                  child: _isGenerating
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminTheme.darkBackground),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.picture_as_pdf_rounded),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Generate & Compile PDF Bill",
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    String hint, {
    TextInputType? keyboardType,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.5)),
            suffixIcon: Icon(icon, color: AdminTheme.primaryYellow, size: 18),
            fillColor: AdminTheme.secondaryBg.withOpacity(0.6),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.primaryYellow, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
          dropdownColor: AdminTheme.darkSurface,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            fillColor: AdminTheme.secondaryBg.withOpacity(0.6),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.primaryYellow, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.secondaryBg.withOpacity(0.6),
        border: Border.all(color: AdminTheme.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          hintText: "Enter spare product code or catalog keyword...",
          hintStyle: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.5), fontFamily: 'Poppins'),
          prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: AdminTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) async {
          if (value.length > 2) {
            setState(() => _isSearching = true);
            try {
              final results = await _apiService.searchParts(value);
              setState(() {
                _searchResults = results;
              });
            } catch (_) {
              setState(() => _searchResults = []);
            } finally {
              setState(() => _isSearching = false);
            }
          } else {
            setState(() => _searchResults = []);
          }
        },
      ),
    );
  }

  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_brand == 'Select Brand') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a compatible brand.', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
          backgroundColor: AdminTheme.primaryYellow,
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
      return;
    }
    if (_selectedParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice must contain at least one spare part.', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
          backgroundColor: AdminTheme.primaryYellow,
          behavior: SnackBarBehavior.floating,
          width: 340,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final payload = {
        "customerName": _customerNameController.text,
        "customerEmail": _customerEmailController.text,
        "warrantyType": _warrantyType == 'Out of Warranty (OW)' ? 'OW' : 'IW',
        "brand": _brand,
        "products": _selectedParts.map((p) => {
          "name": p.partName,
          "qty": 1,
          "rate": p.price,
        }).toList(),
        "serialNumber": _serialNumberController.text,
        "preparedBy": _preparedByController.text,
        "caseId": _caseIdController.text,
        "serviceCharge": double.tryParse(_serviceChargeController.text) ?? 0,
        "gstEnabled": _gstEnabled,
      };

      final response = await _apiService.createInvoice(payload);
      
      final pdfUrl = response['pdfUrl'];
      if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminInvoicePreviewScreen(pdfUrl: pdfUrl),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AdminTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
