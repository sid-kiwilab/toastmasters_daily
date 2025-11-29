import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/version_provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

class VersionBannerWidget extends StatelessWidget {
  final Widget child;
  const VersionBannerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final needsUpdate = context.watch<VersionProvider>().needsUpdate;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: needsUpdate
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.black,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: Offset.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Updated version is available. Please refresh the page.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () {
                              if (kIsWeb) html.window.location.reload();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.refresh,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 0,
                  color: Colors.black,
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

