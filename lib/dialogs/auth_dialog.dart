import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthDialog extends StatefulWidget {
  final int initialTab;
  
  const AuthDialog({super.key, this.initialTab = 0});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signUpFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  
  // Sign up fields
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  
  // Login fields
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  
  bool _isSignUpLoading = false;
  bool _isLoginLoading = false;
  bool _obscureSignUpPassword = true;
  bool _obscureSignUpConfirmPassword = true;
  bool _obscureLoginPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    
    setState(() {
      _isSignUpLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signUp(
        email: _signUpEmailController.text,
        password: _signUpPasswordController.text,
        name: _signUpEmailController.text.split('@')[0], // Use email prefix as name
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create account. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSignUpLoading = false;
        });
      }
    }
  }

  void _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoginLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged in successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Please check your credentials.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Sign Up'),
                  Tab(text: 'Login'),
                ],
              ),
            ),
            
            // Tab content
            SizedBox(
              height: 400, // Fixed height for content area
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Sign Up Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: _buildSignUpTab(theme),
                  ),
                  
                  // Login Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: _buildLoginTab(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpTab(ThemeData theme) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email field
          TextFormField(
            controller: _signUpEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Password field
          TextFormField(
            controller: _signUpPasswordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignUpPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureSignUpPassword = !_obscureSignUpPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            obscureText: _obscureSignUpPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Confirm Password field
          TextFormField(
            controller: _signUpConfirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignUpConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureSignUpConfirmPassword = !_obscureSignUpConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            obscureText: _obscureSignUpConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _signUpPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          
          // Sign Up button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSignUpLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSignUpLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTab(ThemeData theme) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email field
          TextFormField(
            controller: _loginEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Password field
          TextFormField(
            controller: _loginPasswordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureLoginPassword = !_obscureLoginPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            obscureText: _obscureLoginPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          
          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoginLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoginLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}
