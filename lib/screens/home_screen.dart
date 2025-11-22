import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/header_widget.dart';
import '../widgets/footer_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isTyping = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_formatCode);
  }

  Future<bool> _checkClubCodeExists(String clubCode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('club_codes')
          .doc(clubCode)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking club code existence: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _formatCode() {
    final text = _codeController.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.length > 8) {
      _codeController.text = digitsOnly.substring(0, 8);
      _codeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _codeController.text.length),
      );
    } else if (digitsOnly.length > 4) {
      final formatted = '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4)}';
      if (text != formatted) {
        _codeController.text = formatted;
        _codeController.selection = TextSelection.fromPosition(
          TextPosition(offset: _codeController.text.length),
        );
      }
    } else if (digitsOnly.length <= 4 && text.contains(' ')) {
      _codeController.text = digitsOnly;
      _codeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _codeController.text.length),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight + 200, // Extra space to push footer below
                ),
                child: Column(
                  children: [
                    // Header at the top
                    const HeaderWidget(),
                    
                    // Middle section - centers the enter code area vertically
                    SizedBox(
                      height: availableHeight * 0.9,
                      child: Align(
                        alignment: const Alignment(0, -0.15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                      // Decorative gradient accent
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC41E3A),
                              Color(0xFF003366),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Main content
                      Text(
                        'Enter club code to join',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Best speeches coming your way!",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: 280,
                        child: TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            letterSpacing: 8.0,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: _isTyping ? '' : '1234 5678',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              letterSpacing: 8.0,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF2F1F0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 9, // 8 digits + 1 space
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          onTap: () {
                            setState(() {
                              _isTyping = true;
                            });
                          },
                          onChanged: (value) {
                            setState(() {
                              _isTyping = value.isNotEmpty;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC41E3A),
                                Color(0xFF003366),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC41E3A).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isJoining ? null : () async {
                            // Navigate to club page with the entered club code
                            final clubCode = _codeController.text.trim();
                            if (clubCode.isNotEmpty) {
                              // Convert the formatted code (e.g., "1234 5678") to club code format
                              final digitsOnly = clubCode.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digitsOnly.length == 8) {
                                setState(() {
                                  _isJoining = true;
                                });
                                
                                // Check if club code exists
                                final clubCodeExists = await _checkClubCodeExists(digitsOnly);
                                
                                if (clubCodeExists) {
                                  // Navigate to club screen using URL navigation
                                  await Navigator.pushNamed(context, '/clubs/$digitsOnly');
                                } else {
                                  // Show error snackbar
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Club code not found. Please check and try again.'),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                                
                                setState(() {
                                  _isJoining = false;
                                });
                              } else {
                                // Show error snackbar for incomplete code
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Club code must be 8 digits'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              // Show error snackbar for empty code
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a club code'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isJoining 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Join',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const FooterWidget(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
