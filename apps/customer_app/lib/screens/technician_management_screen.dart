import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

class TechnicianManagementScreen extends StatefulWidget {
  const TechnicianManagementScreen({super.key});

  @override
  State<TechnicianManagementScreen> createState() => _TechnicianManagementScreenState();
}

class _TechnicianManagementScreenState extends State<TechnicianManagementScreen> {
  List<dynamic> _technicians = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechnicians() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<SharedApiService>();
      final users = await apiService.getTechnicians();
      if (mounted) {
        setState(() {
          // Filter to technicians or show all
          _technicians = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserStatus(int userId, bool currentStatus) async {
    try {
      final apiService = context.read<SharedApiService>();
      final newStatus = !currentStatus;
      await apiService.updateUserStatus(userId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Technician allowed & activated!' : 'Technician account disabled.'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _fetchTechnicians();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openCreateTechnicianDialog() async {
    final apiService = context.read<SharedApiService>();
    String nextId = 'TECH-0001';
    try {
      nextId = await apiService.getNextTechnicianId();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTechnicianBottomSheet(
        previewId: nextId,
        onSuccess: (createdUser, plainPassword) {
          _fetchTechnicians();
          _showCreatedCredentialsDialog(createdUser, plainPassword);
        },
      ),
    );
  }

  void _showCreatedCredentialsDialog(Map<String, dynamic> user, String plainPassword) {
    final techId = user['technicianId'] ?? user['technician_id'] ?? 'TECH-XXXX';
    final name = user['name'] ?? 'Technician';
    final email = user['email'] ?? 'N/A';

    final fullCredentialsText = '''Electrolyte App - Technician Credentials
Name: $name
Technician ID: $techId
Password: $plainPassword
Login Portal: Electrolyte App''';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Account Created', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The technician login credentials have been created and allowed by Admin successfully.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBlueBg : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCredentialRow('Full Name:', name),
                      const SizedBox(height: 8),
                      _buildCredentialRow('Technician ID:', techId, isHighlight: true),
                      const SizedBox(height: 8),
                      _buildCredentialRow('Password:', plainPassword, isHighlight: true),
                      if (email != 'N/A') ...[
                        const SizedBox(height: 8),
                        _buildCredentialRow('Email:', email),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Credentials'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fullCredentialsText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials copied to clipboard!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCredentialRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? AppTheme.primaryYellow : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkBlueBg : Colors.grey[100];

    final filteredList = _technicians.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final techId = (u['technicianId'] ?? u['technician_id'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || techId.contains(q) || email.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Technician Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: _fetchTechnicians,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryYellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Technician', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreateTechnicianDialog,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppTheme.darkCardColor : Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by technician name, ID, or email...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkBlueBg : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchTechnicians,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.engineering_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty ? 'No technicians match your search.' : 'No technician accounts found.',
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create First Technician'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryYellow,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _openCreateTechnicianDialog,
                                )
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final user = filteredList[index];
                              final id = user['id'] as int? ?? 0;
                              final name = user['name'] ?? 'Technician';
                              final techId = user['technicianId'] ?? user['technician_id'] ?? 'TECH-UNASSIGNED';
                              final email = user['email'] as String?;
                              final phone = user['phone'] as String?;
                              final role = user['role'] ?? 'technician';
                              final isActive = user['isActive'] ?? user['is_active'] ?? true;
                              final createdAt = user['createdAt'] ?? user['created_at'];

                              String formattedDate = '';
                              if (createdAt != null) {
                                try {
                                  formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt));
                                } catch (_) {}
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: role == 'admin'
                                                ? Colors.deepPurple.shade100
                                                : AppTheme.primaryYellow.withValues(alpha: 0.2),
                                            child: Icon(
                                              role == 'admin' ? Icons.admin_panel_settings : Icons.engineering,
                                              color: role == 'admin' ? Colors.deepPurple : Colors.orange.shade800,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryYellow.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: AppTheme.primaryYellow.withValues(alpha: 0.6),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        techId,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.amber,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (email != null && email.isNotEmpty)
                                                  Text(
                                                    email,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                if (phone != null && phone.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      'Phone: $phone',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isActive ? Icons.check_circle : Icons.cancel,
                                                size: 16,
                                                color: isActive ? Colors.green : Colors.red,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isActive ? 'Allowed / Active' : 'Account Disabled',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isActive ? Colors.green : Colors.red,
                                                ),
                                              ),
                                              if (formattedDate.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '• Added $formattedDate',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ]
                                            ],
                                          ),
                                          // Allow / Disable switch
                                          Switch(
                                            value: isActive,
                                            activeThumbColor: AppTheme.primaryYellow,
                                            onChanged: (val) => _toggleUserStatus(id, isActive),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _CreateTechnicianBottomSheet extends StatefulWidget {
  final String previewId;
  final Function(Map<String, dynamic> user, String password) onSuccess;

  const _CreateTechnicianBottomSheet({
    required this.previewId,
    required this.onSuccess,
  });

  @override
  State<_CreateTechnicianBottomSheet> createState() => _CreateTechnicianBottomSheetState();
}

class _CreateTechnicianBottomSheetState extends State<_CreateTechnicianBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isActive = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final apiService = context.read<SharedApiService>();
      final payload = {
        'name': _nameController.text.trim(),
        'password': _passwordController.text,
        'role': 'technician',
        'isActive': _isActive,
      };

      if (_emailController.text.trim().isNotEmpty) {
        payload['email'] = _emailController.text.trim();
      }
      if (_phoneController.text.trim().isNotEmpty) {
        payload['phone'] = _phoneController.text.trim();
      }

      final response = await apiService.createTechnician(payload);
      final createdUser = response['user'] as Map<String, dynamic>;

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess(createdUser, _passwordController.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1, color: AppTheme.primaryYellow, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Create Technician Credentials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Technicians can sign into the mobile app using their assigned ID & password.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),

              // Auto-assigned ID info banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryYellow.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primaryYellow, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Assigned ID: ${widget.previewId} (allocated automatically)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Technician Full Name *',
                  hintText: 'e.g. Adesh Vartak',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter technician full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Password Field (Admin enters manually)
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Login Password *',
                  hintText: 'Enter password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter password';
                  }
                  if (val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Required Technician Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Technician Email *',
                  hintText: 'example@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter technician email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Contact Phone Field (Optional, no predefined value)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Contact Phone (Optional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Allow by Admin toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow & Activate Immediately', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Admin permission to log into the mobile app', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _isActive,
                activeThumbColor: AppTheme.primaryYellow,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Generate & Save Credentials',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
