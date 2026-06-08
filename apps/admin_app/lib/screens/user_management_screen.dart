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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'technician';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      final success = await userProvider.createUser(email, password, _selectedRole);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User credentials created successfully!'),
              backgroundColor: AdminTheme.successColor,
              behavior: SnackBarBehavior.floating,
              width: 320,
            ),
          );
          _emailController.clear();
          _passwordController.clear();
          setState(() {
            _selectedRole = 'technician';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userProvider.errorMessage ?? 'Failed to create user.'),
              backgroundColor: AdminTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              width: 320,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: User Creation Form
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
                          'Create New Credentials',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        // const SizedBox(height: 6),
                        // const Text(
                        //   'Access levels define which applications the user can log into.',
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     color: AdminTheme.textSecondary,
                        //     fontFamily: 'Poppins',
                        //   ),
                        // ),
                        const SizedBox(height: 32),
                        
                        // Email Input
                        const Text(
                          'Email',
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
                            hintText: 'e.g. technician@electrolyte.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18, color: AdminTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
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
                            hintText: '••••••••',
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
                        const SizedBox(height: 24),
                        
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
                          value: _selectedRole,
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
                        const SizedBox(height: 36),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
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
                                        'Create',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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
            const SizedBox(width: 40),
            
            // Right Column: Registered Users Tracker List
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: AdminTheme.glassBox(opacity: 0.2, radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Users',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 6),
                            // Text(
                            //   'Logs of all admin and technician access credentials.',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     color: AdminTheme.textSecondary,
                            //     fontFamily: 'Poppins',
                            //   ),
                            // ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AdminTheme.primaryYellow),
                          onPressed: userProvider.fetchUsers,
                          tooltip: 'Refresh Users list',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    Expanded(
                      child: userProvider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: AdminTheme.primaryYellow),
                            )
                          : userProvider.users.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No registered users found.',
                                    style: TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins'),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(AdminTheme.sidebarBg),
                                        dataRowColor: MaterialStateProperty.all(AdminTheme.secondaryBg.withOpacity(0.3)),
                                        border: TableBorder.all(color: AdminTheme.borderColor, width: 1, borderRadius: BorderRadius.circular(8)),
                                        columns: const [
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
                                        ],
                                        rows: userProvider.users.map((user) {
                                          final role = user['role'] as String? ?? 'technician';
                                          final email = user['email'] as String? ?? '';
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
                                              DataCell(
                                                Text(
                                                  email,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isAdmin
                                                        ? AdminTheme.successColor.withOpacity(0.1)
                                                        : AdminTheme.primaryYellow.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isAdmin
                                                          ? AdminTheme.successColor.withOpacity(0.4)
                                                          : AdminTheme.primaryYellow.withOpacity(0.4),
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
                                              DataCell(
                                                Text(
                                                  dateFormatted,
                                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontFamily: 'Poppins'),
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
