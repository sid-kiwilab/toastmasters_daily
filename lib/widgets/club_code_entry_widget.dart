import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ClubCodeEntryWidget extends StatefulWidget {
  const ClubCodeEntryWidget({super.key});

  @override
  State<ClubCodeEntryWidget> createState() => _ClubCodeEntryWidgetState();
}

class _ClubCodeEntryWidgetState extends State<ClubCodeEntryWidget> {
  final TextEditingController _codeController = TextEditingController();
  bool _isTyping = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_formatCode);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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

  Future<void> _handleJoin() async {
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
          if (mounted) {
            // Close dialog if we're in one
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            await Navigator.pushNamed(context, '/clubs/$digitsOnly');
          }
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
        
        if (mounted) {
          setState(() {
            _isJoining = false;
          });
        }
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative gradient accent
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors.primaryButtonGradient,
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
            color: const Color(0xFF212121),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Best speeches coming your way!",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            color: const Color(0xFF6B7280),
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
                color: const Color(0xFF9CA3AF),
                letterSpacing: 8.0,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primaryButtonGradient.first, width: 2),
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
              gradient: LinearGradient(
                colors: colors.primaryButtonGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colors.buttonShadow.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isJoining ? null : _handleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }
}

