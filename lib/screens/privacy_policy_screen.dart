import 'package:flutter/material.dart';
import '../widgets/footer_widget.dart';
import '../widgets/header_widget.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                constraints: const BoxConstraints(maxWidth: 1200),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privacy Policy',
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
                      '1. Introduction',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Toastmasters Daily ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our application.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '2. Information We Collect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We collect information that you provide directly to us, including:\n\n• Account information (email address, name)\n• Meeting information (meeting codes, agendas, polls)\n• Club information (club name, club info, club codes)\n• Usage data and analytics',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '3. How We Use Your Information',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process transactions and send related information\n• Send technical notices and support messages\n• Respond to your comments and questions\n• Monitor and analyze trends and usage',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '4. Data Storage and Security',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your data is stored securely using Firebase services. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '5. Third-Party Services',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We use Firebase (Google) for authentication, database, and storage services. Your use of these services is subject to their respective privacy policies.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '6. Your Rights',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You have the right to:\n\n• Access your personal information\n• Correct inaccurate data\n• Request deletion of your account and data\n• Object to processing of your information\n• Export your data',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '7. Contact Us',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'If you have any questions about this Privacy Policy, please contact us through the app or visit our support page.',
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

