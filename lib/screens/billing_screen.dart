import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/spare_part.dart';
import '../theme/app_theme.dart';
import 'invoice_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
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
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        title: const Text(
          'Create Invoice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Please fill in the details",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              _buildDropdownField(
                "Warranty Type",
                _warrantyType,
                ['Out of Warranty (OW)', 'In Warranty (IW)'],
                (val) {
                  setState(() => _warrantyType = val!);
                },
              ),

              _buildTextField("Customer Name", Icons.person, "Enter name", controller: _customerNameController),
              _buildTextField("Customer Email", Icons.email, "Enter email", controller: _customerEmailController),

              _buildDropdownField(
                "Select Brand",
                _brand,
                ['Select Brand', 'Atomberg', 'Symphony', 'Bajaj'],
                (val) {
                  setState(() => _brand = val!);
                },
              ),

              const SizedBox(height: 16),
              const Text(
                "Search Product",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSearchField(),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_searchResults.isNotEmpty)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final part = _searchResults[index];
                      return ListTile(
                        title: Text(part.partName),
                        subtitle: Text("${part.partCode} - ${part.model}"),
                        trailing: Text("₹${part.price}"),
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

              const SizedBox(height: 16),
              const Text(
                "Selected Products",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),
              if (_selectedParts.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedParts.length,
                  itemBuilder: (context, index) {
                    final part = _selectedParts[index];
                    return Card(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.1),
                      child: ListTile(
                        title: Text(part.partName),
                        subtitle: Text(
                          "${part.partCode} | ₹${part.price}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _selectedParts.removeAt(index)),
                        ),
                      ),
                    );
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "No products selected",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              _buildTextField(
                "Serial Number",
                Icons.grid_3x3,
                "Enter serial number",
                controller: _serialNumberController,
              ),
              _buildTextField(
                "Prepared By",
                Icons.person_outline,
                "DIPAK MOHITE",
                controller: _preparedByController,
              ),
              _buildTextField(
                "Case ID",
                Icons.confirmation_number_outlined,
                "Enter case ID",
                controller: _caseIdController,
              ),
              _buildTextField(
                "Service Charge",
                Icons.attach_money,
                "0",
                keyboardType: TextInputType.number,
                controller: _serviceChargeController,
              ),

              Row(
                children: [
                  Checkbox(
                    value: _gstEnabled,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (val) {
                      setState(() => _gstEnabled = val ?? false);
                    },
                  ),
                  const Text(
                    "Apply GST (18%)",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "Generate Invoice",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: Icon(icon, color: const Color(0xFFFFC107)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          DropdownButtonFormField<String>(
            initialValue: value,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Enter product name or ID",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          border: InputBorder.none,
        ),
        onChanged: (value) async {
          if (value.length > 2) {
            setState(() => _isSearching = true);
            try {
              final results = await _apiService.searchParts(value);
              setState(() {
                _searchResults = results;
              });
            } catch (e) {
              debugPrint("Search error: $e");
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
    if (_selectedParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product')),
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Invoice generated!')),
        );
      }

      final pdfUrl = response['pdfUrl'];
      if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvoicePreviewScreen(pdfUrl: pdfUrl),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
