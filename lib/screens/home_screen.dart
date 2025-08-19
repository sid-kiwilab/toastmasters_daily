import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/header_widget.dart';
import '../widgets/footer_widget.dart';
import 'view_meeting_screen.dart';
import '../main.dart';

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
  double? _initialViewportHeight;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_formatCode);
    // Capture initial viewport height - this won't change after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _initialViewportHeight = MediaQuery.of(context).size.height;
        });
      }
    });
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
      // Remove any spaces and ensure it's exactly 8 digits
      final cleanMeetingId = meetingId.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cleanMeetingId.length != 8) {
        return false;
      }
      
      final doc = await FirebaseFirestore.instance
          .collection('active_meetings')
          .doc(cleanMeetingId)
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
       resizeToAvoidBottomInset: false,
       body: SafeArea(
         child: SingleChildScrollView(
           physics: const ClampingScrollPhysics(),
           child: Column(
                            children: [
                 // Header at the top
                 const HeaderWidget(),
                 
                                   // Spacer to center main content on viewport
                  SizedBox(height: (_initialViewportHeight ?? MediaQuery.of(context).size.height) * 0.22),
                 
                                                      // Main content
                   Text(
                     'Enter the code to join',
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
                     child: ElevatedButton(
                       onPressed: _isJoining ? null : () async {
                         // Clear any previous error
                         setState(() {
                           _errorMessage = null;
                         });
                         
                         // Navigate to view meeting screen with the entered code
                         final meetingCode = _codeController.text.trim();
                         if (meetingCode.isNotEmpty) {
                           // Convert the formatted code (e.g., "1234 5678") to meeting ID format
                           final digitsOnly = meetingCode.replaceAll(RegExp(r'[^0-9]'), '');
                           if (digitsOnly.length == 8) {
                             setState(() {
                               _isJoining = true;
                             });
                             
                                                           final meetingId = digitsOnly;
                              
                              // Check if meeting exists first
                              final meetingExists = await _checkMeetingExists(meetingId);
                              
                              if (meetingExists) {
                                // Navigate to view meeting screen using URL navigation
                                await Navigator.pushNamed(context, '/meetings/$meetingId');
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
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.grey[800],
                         foregroundColor: Colors.white,
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
                  // Show error message below the button
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
               
               // Footer at the bottom
               const FooterWidget(),
             ],
           ),
         ),
       ),
     );
  }
}
