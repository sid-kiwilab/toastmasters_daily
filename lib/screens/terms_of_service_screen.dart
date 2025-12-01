import 'package:flutter/material.dart';
import '../widgets/footer_widget.dart';
import '../widgets/header_widget.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const HeaderWidget(),
              
              // Content
              Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Last Updated: ${DateTime.now().year}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '1. Acceptance of Terms',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'By accessing and using Toastmasters Daily, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '2. Use License',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Permission is granted to temporarily use Toastmasters Daily for personal, non-commercial use only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n• Modify or copy the materials\n• Use the materials for any commercial purpose\n• Attempt to decompile or reverse engineer any software\n• Remove any copyright or other proprietary notations',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '3. User Accounts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You are responsible for maintaining the confidentiality of your account credentials. You agree to:\n\n• Provide accurate and complete information\n• Keep your password secure\n• Notify us immediately of any unauthorized use\n• Accept responsibility for all activities under your account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '4. User Conduct',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You agree not to use the service to:\n\n• Violate any laws or regulations\n• Infringe on the rights of others\n• Transmit harmful or malicious code\n• Interfere with the service\'s operation\n• Harass, abuse, or harm other users',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '5. Content and Intellectual Property',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All content, features, and functionality of Toastmasters Daily are owned by Kiwi Lab and are protected by international copyright, trademark, and other intellectual property laws. You retain ownership of content you create, but grant us a license to use it in providing the service.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '6. Disclaimer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'The materials on Toastmasters Daily are provided on an "as is" basis. Kiwi Lab makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '7. Limitation of Liability',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'In no event shall Kiwi Lab or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use Toastmasters Daily.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '8. Termination',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We may terminate or suspend your account and access to the service immediately, without prior notice, for conduct that we believe violates these Terms of Service or is harmful to other users, us, or third parties.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '9. Changes to Terms',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We reserve the right to modify these terms at any time. We will notify users of any material changes. Your continued use of the service after such modifications constitutes acceptance of the updated terms.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '10. Contact Information',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'If you have any questions about these Terms of Service, please contact us through the app or visit our support page.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const FooterWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

