import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../utils/theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedRole = 'technician';
  bool _obscurePassword = true;
  String _previewNextId = 'Loading...';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNextTechnicianId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNextTechnicianId() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final nextId = await userProvider.getNextTechnicianId();
      if (mounted) {
        setState(() {
          _previewNextId = nextId;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _previewNextId = 'TECH-0001';
        });
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      final success = await userProvider.createUser(
        email,
        password,
        _selectedRole,
        name: name.isNotEmpty ? name : null,
        phone: phone.isNotEmpty ? phone : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Technician credentials created successfully!'),
              backgroundColor: AdminTheme.successColor,
              behavior: SnackBarBehavior.floating,
              width: 340,
            ),
          );
          _nameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _phoneController.clear();
          setState(() {
            _selectedRole = 'technician';
          });
          _loadNextTechnicianId();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userProvider.errorMessage ?? 'Failed to create user.'),
              backgroundColor: AdminTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              width: 340,
            ),
          );
        }
      }
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    final techId = user['technician_id'] ?? user['technicianId'] ?? '';
    final name = user['name'] ?? 'Technician';
    final email = user['email'] ?? '';
    final userId = user['id'];
    final displayIdentifier = techId.toString().isNotEmpty ? techId.toString() : (name.isNotEmpty ? name : 'ID #$userId');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AdminTheme.sidebarBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.errorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AdminTheme.errorColor, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Technician Account?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5, fontFamily: 'Poppins'),
                    children: [
                      const TextSpan(text: 'Are you sure you want to delete technician ID '),
                      TextSpan(
                        text: displayIdentifier,
                        style: const TextStyle(color: AdminTheme.primaryYellow, fontWeight: FontWeight.bold),
                      ),
                      if (email.isNotEmpty) ...[
                        const TextSpan(text: ' ('),
                        TextSpan(text: email, style: const TextStyle(color: Colors.white)),
                        const TextSpan(text: ')'),
                      ],
                      const TextSpan(
                        text: '?\n\nDeleting this technician ID will permanently delete the entire account and revoke all login credentials.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.darkBackground.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AdminTheme.successColor, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Historical invoices & billing records prepared by this technician will be preserved for financial audit.',
                          style: TextStyle(
                            color: AdminTheme.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins')),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final idToDelete = techId.toString().isNotEmpty ? techId : userId;
                final success = await userProvider.deleteUser(idToDelete);

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Technician account ($displayIdentifier) deleted permanently.'),
                        backgroundColor: AdminTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                        width: 380,
                      ),
                    );
                    _loadNextTechnicianId();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(userProvider.errorMessage ?? 'Failed to delete technician account.'),
                        backgroundColor: AdminTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        width: 380,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  void _openDeleteByIdDialog() {
    final deleteIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AdminTheme.sidebarBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.borderColor),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_remove_outlined, color: AdminTheme.errorColor, size: 24),
              SizedBox(width: 10),
              Text(
                'Delete by Technician ID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the Technician ID (e.g. TECH-0001) or Email to permanently delete the account:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: deleteIdController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    hintText: 'e.g. TECH-0001 or email@domain.com',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AdminTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final targetId = deleteIdController.text.trim();
                if (targetId.isEmpty) return;
                Navigator.of(dialogCtx).pop();

                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final success = await userProvider.deleteUser(targetId);

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Technician account ($targetId) deleted successfully.'),
                        backgroundColor: AdminTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                        width: 360,
                      ),
                    );
                    _loadNextTechnicianId();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(userProvider.errorMessage ?? 'Failed to delete technician.'),
                        backgroundColor: AdminTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        width: 360,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Filter users list based on search query
    final filteredUsers = userProvider.users.where((user) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (user['name'] ?? '').toString().toLowerCase();
      final techId = (user['technician_id'] ?? user['technicianId'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || techId.contains(q) || email.contains(q) || role.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: User / Technician Creation Form
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: AdminTheme.glassBox(opacity: 0.2, radius: 16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Technician Credentials',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create and authorize accounts for technicians or admins.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AdminTheme.textSecondary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Auto-assigned preview badge
                        if (_selectedRole == 'technician') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AdminTheme.darkBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdminTheme.primaryYellow.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined, color: AdminTheme.primaryYellow, size: 20),
                                const SizedBox(width: 10),
                                const Text(
                                  'Next Assigned ID: ',
                                  style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary, fontFamily: 'Poppins'),
                                ),
                                Text(
                                  _previewNextId,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AdminTheme.primaryYellow,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Full Name Input
                        const Text(
                          'Full Name',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Adesh Vartak',
                            prefixIcon: Icon(Icons.person_outline, size: 18, color: AdminTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email Input
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'e.g. technician@gmail.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18, color: AdminTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password Input
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter account password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AdminTheme.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: AdminTheme.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Phone Input (Optional)
                        const Text(
                          'Phone Number (Optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. +91 98765 43210',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AdminTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Role Dropdown
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          dropdownColor: AdminTheme.sidebarBg,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                          items: const [
                            DropdownMenuItem(
                              value: 'technician',
                              child: Text('Technician'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedRole = val;
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.shield_outlined, size: 18, color: AdminTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primaryYellow,
                              foregroundColor: AdminTheme.darkBackground,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: userProvider.isCreating ? null : _submit,
                            child: userProvider.isCreating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: AdminTheme.darkBackground,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_alt_1_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Technician Credentials',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 32),

            // Right Column: Registered Users & Technicians Tracker List
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: AdminTheme.glassBox(opacity: 0.2, radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Title, Search, and Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registered Technicians & Accounts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage technician credentials and accounts.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminTheme.textSecondary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Delete by ID quick button
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AdminTheme.errorColor,
                                side: BorderSide(color: AdminTheme.errorColor.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _openDeleteByIdDialog,
                              icon: const Icon(Icons.person_remove_outlined, size: 16),
                              label: const Text(
                                'Delete by ID',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Refresh list
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: AdminTheme.primaryYellow),
                              onPressed: () {
                                userProvider.fetchUsers();
                                _loadNextTechnicianId();
                              },
                              tooltip: 'Refresh list',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search input
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          hintText: 'Search by technician ID, name, or email...',
                          hintStyle: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AdminTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: AdminTheme.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Table
                    Expanded(
                      child: userProvider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: AdminTheme.primaryYellow),
                            )
                          : filteredUsers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.engineering_outlined, size: 48, color: AdminTheme.textSecondary),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty ? 'No accounts match "$_searchQuery"' : 'No registered users found.',
                                        style: const TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins'),
                                      ),
                                    ],
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(AdminTheme.sidebarBg),
                                        dataRowColor: WidgetStateProperty.all(AdminTheme.secondaryBg.withValues(alpha: 0.3)),
                                        border: TableBorder.all(color: AdminTheme.borderColor, width: 1, borderRadius: BorderRadius.circular(8)),
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Technician ID',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Name',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Email',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Role',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Date Created',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Actions',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                            ),
                                          ),
                                        ],
                                        rows: filteredUsers.map((user) {
                                          final role = user['role'] as String? ?? 'technician';
                                          final name = user['name'] as String? ?? 'Technician';
                                          final techId = user['technician_id'] ?? user['technicianId'] ?? '—';
                                          final email = user['email'] as String? ?? '—';
                                          final createdAtStr = user['created_at'] as String?;

                                          DateTime? createdAt;
                                          if (createdAtStr != null) {
                                            try {
                                              createdAt = DateTime.parse(createdAtStr).toLocal();
                                            } catch (_) {}
                                          }
                                          final dateFormatted = createdAt != null
                                              ? DateFormat('MMM dd, yyyy  hh:mm a').format(createdAt)
                                              : 'N/A';

                                          final isAdmin = role == 'admin';

                                          return DataRow(
                                            cells: [
                                              // Technician ID badge
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AdminTheme.primaryYellow.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: AdminTheme.primaryYellow.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    techId.toString(),
                                                    style: const TextStyle(
                                                      color: AdminTheme.primaryYellow,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Name
                                              DataCell(
                                                Text(
                                                  name,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                                                ),
                                              ),
                                              // Email
                                              DataCell(
                                                Text(
                                                  email,
                                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins'),
                                                ),
                                              ),
                                              // Role
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isAdmin
                                                        ? AdminTheme.successColor.withValues(alpha: 0.1)
                                                        : AdminTheme.primaryYellow.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isAdmin
                                                          ? AdminTheme.successColor.withValues(alpha: 0.4)
                                                          : AdminTheme.primaryYellow.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    role.toUpperCase(),
                                                    style: TextStyle(
                                                      color: isAdmin
                                                          ? AdminTheme.successColor
                                                          : AdminTheme.primaryYellow,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Date Created
                                              DataCell(
                                                Text(
                                                  dateFormatted,
                                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontFamily: 'Poppins'),
                                                ),
                                              ),
                                              // Actions: Delete Button
                                              DataCell(
                                                isAdmin
                                                    ? const SizedBox.shrink()
                                                    : IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, color: AdminTheme.errorColor, size: 20),
                                                        tooltip: 'Delete Technician ID & Account',
                                                        hoverColor: AdminTheme.errorColor.withValues(alpha: 0.15),
                                                        onPressed: () => _confirmDeleteUser(user),
                                                      ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
