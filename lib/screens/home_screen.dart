import 'package:flutter/material.dart';
import '../widgets/footer_widget.dart';
import '../widgets/header_widget.dart';
import '../widgets/home_banner_widget.dart';
import '../widgets/action_tiles_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const HeaderWidget(),
              // Centered content with max width
              Center(
                child: Column(
                  children: [
                    const HomeBannerWidget(),
                    const ActionTilesWidget(),
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
