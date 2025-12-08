import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.footerGradient,
            ),
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
            Divider(
              color: Colors.white.withOpacity(0.2),
              thickness: 1,
            ),
            SizedBox(height: isMobile ? 16 : 24),
            // Copyright and Made with ❤️
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Made with ❤️ for Toastmasters',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.footerAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© ${DateTime.now().year} Kiwi Lab. All rights reserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© ${DateTime.now().year} Kiwi Lab. All rights reserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        'Made with ❤️ for Toastmasters',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.footerAccent,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildFooterLink(String text, Future<void> Function()? onTap) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
