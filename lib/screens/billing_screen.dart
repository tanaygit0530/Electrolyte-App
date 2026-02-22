import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // ADD THIS IMPORT

// Adjust these imports to match your actual paths
// import '../services/api_service.dart';
// import '../models/spare_part.dart';
// import '../theme/app_theme.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const Color _primaryColor = Color(0xFFFFC107);
  
  final _formKey = GlobalKey<FormState>();
  
  // --- THE BLIND SPOT FIX: Controllers to actually hold the data ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _serialController = TextEditingController();
  final _caseIdController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  final _preparedByController = TextEditingController();

  String _warrantyType = 'Out of Warranty (OW)';
  String _brand = 'Select Brand';

  List<dynamic> _searchResults = []; 
  dynamic _selectedPart; 
  
  bool _isSearching = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    // --- MEMORY LEAK PREVENTION ---
    _nameController.dispose();
    _emailController.dispose();
    _serialController.dispose();
    _caseIdController.dispose();
    _serviceChargeController.dispose();
    _preparedByController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- THE SHARE LOGIC ---
  void _shareInvoiceData() {
    // 1. Gather the actual data from the controllers
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final serial = _serialController.text.trim();
    final caseId = _caseIdController.text.trim();
    final serviceCharge = _serviceChargeController.text.trim();
    final preparedBy = _preparedByController.text.trim();

    // 2. Format it cleanly
    final StringBuffer shareText = StringBuffer();
    shareText.writeln("INVOICE SUMMARY");
    shareText.writeln("-----------------");
    shareText.writeln("Customer: ${name.isEmpty ? 'N/A' : name}");
    shareText.writeln("Email: ${email.isEmpty ? 'N/A' : email}");
    shareText.writeln("Brand: $_brand");
    shareText.writeln("Warranty: $_warrantyType");
    
    if (_selectedPart != null) {
      shareText.writeln("Part: ${_selectedPart['partName']} (${_selectedPart['partCode']})");
      shareText.writeln("Part Price: ₹${_selectedPart['price']}");
    } else {
      shareText.writeln("Part: None selected");
    }
    
    shareText.writeln("Serial Number: ${serial.isEmpty ? 'N/A' : serial}");
    shareText.writeln("Case ID: ${caseId.isEmpty ? 'N/A' : caseId}");
    shareText.writeln("Service Charge: ₹${serviceCharge.isEmpty ? '0' : serviceCharge}");
    shareText.writeln("Prepared By: ${preparedBy.isEmpty ? 'N/A' : preparedBy}");

    // 3. Trigger native share
    Share.share(shareText.toString(), subject: 'Invoice Details: $caseId');
  }

  void _onSearchChanged(String query) {
    if (query.length <= 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() => _isSearching = true);
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await Future.delayed(const Duration(milliseconds: 600)); 
        final all = [
          {'partName': 'Display Panel', 'partCode': 'DP-001', 'model': 'Galaxy S21', 'price': 4500},
          {'partName': 'Battery Pack', 'partCode': 'BP-002', 'model': 'LG TV', 'price': 1200},
        ];

        if (!mounted) return;
        setState(() {
          _searchResults = all.where((p) {
            final partName = p['partName'].toString().toLowerCase();
            final partCode = p['partCode'].toString().toLowerCase();
            final q = query.toLowerCase();
            return partName.contains(q) || partCode.contains(q);
          }).toList();
        });
      } catch (e) {
        debugPrint("Search error: $e");
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
        title: const Text(
          'Create Invoice',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded), onPressed: () {}),
          // --- CONNECTED SHARE BUTTON ---
          IconButton(
            icon: const Icon(Icons.share_rounded), 
            onPressed: _shareInvoiceData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                title: "Customer Information",
                icon: Icons.person_outline_rounded,
                children: [
                  // --- PASSED CONTROLLERS TO TEXT FIELDS ---
                  _buildTextField("Customer Name", Icons.badge_outlined, "e.g. John Doe", controller: _nameController),
                  const SizedBox(height: 16),
                  _buildTextField("Customer Email", Icons.email_outlined, "e.g. john@example.com", keyboardType: TextInputType.emailAddress, controller: _emailController),
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionCard(
                title: "Product & Warranty",
                icon: Icons.devices_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          "Brand",
                          _brand,
                          ['Select Brand', 'Samsung', 'LG', 'Sony'],
                          (val) => setState(() => _brand = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField(
                          "Warranty",
                          _warrantyType,
                          ['Out of Warranty (OW)', 'In Warranty (IW)'],
                          (val) => setState(() => _warrantyType = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Search Spare Part", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 8),
                  _buildSearchField(),
                  
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
                      ),
                    ),
                    
                  if (_searchResults.isNotEmpty && _selectedPart == null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, index) {
                          final part = _searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(part['partName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text("${part['partCode']} • ${part['model']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            trailing: Text("₹${part['price']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            onTap: () {
                              setState(() {
                                _selectedPart = part;
                                _searchResults = [];
                                _searchController.text = part['partName'];
                              });
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),

                  if (_selectedPart != null) ...[
                    const SizedBox(height: 16),
                    _buildSelectedPartCard(),
                  ]
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionCard(
                title: "Billing Details",
                icon: Icons.receipt_long_rounded,
                children: [
                  _buildTextField("Serial Number", Icons.qr_code_rounded, "Enter S/N", controller: _serialController),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("Case ID", Icons.tag_rounded, "Ticket/Case #", controller: _caseIdController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField("Service Charge", Icons.currency_rupee_rounded, "0.00", keyboardType: TextInputType.number, controller: _serviceChargeController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField("Prepared By", Icons.engineering_rounded, "Technician Name", controller: _preparedByController),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Process Invoice
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Review & Generate Invoice",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.amber.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // --- ADDED CONTROLLER PARAMETER ---
  Widget _buildTextField(String label, IconData icon, String hint, {TextInputType? keyboardType, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, // <-- APPLIED HERE
          keyboardType: keyboardType,
          decoration: _inputDecoration(hint, icon),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.expand_more_rounded, color: Colors.grey),
          items: items.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(
              e, 
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            )
          )).toList(),
          onChanged: onChanged,
          decoration: _inputDecoration("", null),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextFormField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: _inputDecoration("Search by name or ID...", Icons.search_rounded).copyWith(
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _selectedPart = null;
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildSelectedPartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedPart['partName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text("${_selectedPart['partCode']}  •  ₹${_selectedPart['price']}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => setState(() {
              _selectedPart = null;
              _searchController.clear();
            }),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500, size: 20) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}