import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/header_widget.dart';
import '../widgets/footer_widget.dart';
import 'view_meeting_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isTyping = false;
  bool _isJoining = false;
  String? _errorMessage;

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

  Future<bool> _checkMeetingExists(String meetingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('active_meetings')
          .doc(meetingId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header at the top
              const HeaderWidget(),
              
              // Main content
              SizedBox(
                height: MediaQuery.of(context).size.height - 200, // Adjust for header and bottom
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Toastmasters Daily title right above the container
                      Text(
                        'Toastmasters Daily',
                        style: theme.textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 400,
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.onSurface.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Join Meeting',
                              style: theme.textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Enter the 8-digit meeting code',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: 200,
                              child: TextField(
                                controller: _codeController,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  letterSpacing: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: _isTyping ? '' : '3927 9034',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    letterSpacing: 8.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
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
                              width: 200,
                              child: ElevatedButton(
                                onPressed: _isJoining ? null : () async {
                                  // Clear any previous error
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                  
                                                                     // Navigate to view meeting screen with the entered code
                                   final meetingCode = _codeController.text.trim();
                                   if (meetingCode.isNotEmpty) {
                                     // Convert the formatted code (e.g., "3927 9034") to meeting ID format
                                     final digitsOnly = meetingCode.replaceAll(RegExp(r'[^0-9]'), '');
                                     if (digitsOnly.length == 8) {
                                       setState(() {
                                         _isJoining = true;
                                       });
                                       
                                       final meetingId = '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4)}';
                                       
                                       // Check if meeting exists first
                                       final meetingExists = await _checkMeetingExists(meetingId);
                                       
                                       if (meetingExists) {
                                         // Navigate to view meeting screen using URL navigation
                                         final urlMeetingId = meetingId.replaceAll(' ', '');
                                         await Navigator.pushNamed(context, '/meetings/$urlMeetingId');
                                       } else {
                                         // Show error message on the same screen
                                         setState(() {
                                           _errorMessage = 'Meeting not found';
                                         });
                                       }
                                       
                                       setState(() {
                                         _isJoining = false;
                                       });
                                     } else {
                                       // Show error message for incomplete code
                                       setState(() {
                                         _errorMessage = 'Code must be 8 digits';
                                       });
                                     }
                                   } else {
                                     // Show error message for empty code
                                     setState(() {
                                       _errorMessage = 'Please enter a meeting code';
                                     });
                                   }
                                },
                                child: _isJoining 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Join Meeting'),
                              ),
                            ),
                            // Show error message below the button
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Version number right below the white container
                      Text(
                        'Version: 1.0.0',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer at the bottom
              const FooterWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
