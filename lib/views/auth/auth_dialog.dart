import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/board_provider.dart';
import '../../services/api_service.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool isLoading = false;
  String? error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => error = 'Please fill in required fields');
      return;
    }

    if (!isLogin) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => error = 'Please enter your name');
        return;
      }
      if (password != confirmPassword) {
        setState(() => error = 'Passwords do not match');
        return;
      }
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    Map<String, dynamic> res = isLogin
        ? await ApiService.login(email, password)
        : await ApiService.register(_nameController.text.trim(), email, password);

    setState(() => isLoading = false);

    if (res.containsKey('token')) {
      if (mounted) {
        final responseUser = res['user'];
        String? fullName;

        if (responseUser is Map) {
          fullName = (responseUser['fullName'] ?? responseUser['name'])?.toString();
        }

        // Some AuthResponse implementations expose the name directly.
        fullName ??= (res['fullName'] ?? res['name'])?.toString();

        // The backend may return only the token for login. In that case,
        // retain a sensible display fallback rather than pinning the whole
        // email address.
        final displayName = fullName?.trim().isNotEmpty == true
            ? fullName!.trim().split(RegExp(r'\s+')).first
            : email.split('@').first;

        context.read<BoardProvider>().setSession(
          res['token'].toString(),
          email,
          displayName: displayName,
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        error = res['error'] ?? 'Authentication failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF252526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        isLogin ? 'Login' : 'Create Account',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],
              if (!isLogin) ...[
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: Colors.grey)),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Confirm Password', labelStyle: TextStyle(color: Colors.grey)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            isLogin = !isLogin;
            error = null;
          }),
          child: Text(
            isLogin ? 'Need an account? Register' : 'Have an account? Login',
            style: const TextStyle(color: Colors.blueAccent),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
            isLogin ? 'Login' : 'Register',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}