import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF212121),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 32 : 48,
        horizontal: isMobile ? 16 : 20,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legal and Connect Sections
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legal Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Legal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFooterLink('Privacy Policy', () async {
                            Navigator.of(context).pushNamed('/privacy');
                          }),
                          const SizedBox(height: 8),
                          _buildFooterLink('Terms of Service', () async {
                            Navigator.of(context).pushNamed('/terms');
                          }),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Connect Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFooterLink('Toastmasters International', () async {
                            final uri = Uri.parse('https://www.toastmasters.org/');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }),
                          const SizedBox(height: 8),
                          _buildFooterLink('Find a Club', () async {
                            final uri = Uri.parse('https://www.toastmasters.org/find-a-club');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legal Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Legal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFooterLink('Privacy Policy', () async {
                              Navigator.of(context).pushNamed('/privacy');
                            }),
                            const SizedBox(height: 8),
                            _buildFooterLink('Terms of Service', () async {
                              Navigator.of(context).pushNamed('/terms');
                            }),
                          ],
                        ),
                      ),
                      // Connect Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connect',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFooterLink('Toastmasters International', () async {
                              final uri = Uri.parse('https://www.toastmasters.org/');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }),
                            const SizedBox(height: 8),
                            _buildFooterLink('Find a Club', () async {
                              final uri = Uri.parse('https://www.toastmasters.org/find-a-club');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
            SizedBox(height: isMobile ? 24 : 32),
            const Divider(
              color: Color(0xFF424242),
              thickness: 1,
            ),
            SizedBox(height: isMobile ? 16 : 24),
            // Copyright and Made with ❤️
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '© ${DateTime.now().year} Kiwi Lab. All rights reserved.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Made with ❤️ for Toastmasters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© ${DateTime.now().year} Kiwi Lab. All rights reserved.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const Text(
                        'Made with ❤️ for Toastmasters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, Future<void> Function()? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFBDBDBD),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

