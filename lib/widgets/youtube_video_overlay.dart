import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'dart:ui_web' as ui_web if (dart.library.html) 'dart:ui_web';

class YoutubeVideoOverlay extends StatefulWidget {
  final String videoId;

  const YoutubeVideoOverlay({
    super.key,
    required this.videoId,
  });

  @override
  State<YoutubeVideoOverlay> createState() => _YoutubeVideoOverlayState();
}

class _YoutubeVideoOverlayState extends State<YoutubeVideoOverlay> {
  String? _iframeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _iframeId = 'youtube-iframe-${DateTime.now().millisecondsSinceEpoch}';
      _registerIframe();
    }
  }

  void _registerIframe() {
    if (kIsWeb && _iframeId != null) {
      // Create iframe element
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/${widget.videoId}?autoplay=1'
        ..style.border = 'none'
        ..allowFullscreen = true
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';

      // Register the iframe
      ui_web.platformViewRegistry.registerViewFactory(
        _iframeId!,
        (int viewId) => iframe,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: kIsWeb && _iframeId != null
                ? HtmlElementView(viewType: _iframeId!)
                : const Center(
                    child: Text(
                      'Video player not available',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

