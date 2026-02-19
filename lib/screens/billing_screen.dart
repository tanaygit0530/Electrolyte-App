import 'package:flutter/material.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _warrantyType = 'Out of Warranty (OW)';
  String _brand = 'Select Brand';

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

              _buildTextField("Customer Name", Icons.person, "Enter name"),
              _buildTextField("Customer Email", Icons.email, "Enter email"),

              _buildDropdownField(
                "Select Brand",
                _brand,
                ['Select Brand', 'Samsung', 'LG', 'Sony'],
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

              const SizedBox(height: 16),
              const Text(
                "Selected Products",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),

              _buildTextField(
                "Serial Number",
                Icons.grid_3x3,
                "Enter serial number",
              ),
              _buildTextField(
                "Prepared By",
                Icons.person_outline,
                "DIPAK MOHITE",
              ),
              _buildTextField(
                "Case ID",
                Icons.confirmation_number_outlined,
                "Enter case ID",
              ),
              _buildTextField(
                "Service Charge",
                Icons.attach_money,
                "0",
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Processing Invoice...")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    "View Summary",
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          TextFormField(
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
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Enter product name or ID",
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
