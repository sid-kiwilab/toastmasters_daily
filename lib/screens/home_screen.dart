import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                                onPressed: () {
                                  // Add join meeting logic here
                                },
                                child: const Text('Join Meeting'),
                              ),
                            ),
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
