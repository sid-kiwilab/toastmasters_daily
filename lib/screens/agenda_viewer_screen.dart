import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class AgendaViewerScreen extends StatefulWidget {
  final String agendaUrl;

  const AgendaViewerScreen({super.key, required this.agendaUrl});

  @override
  State<AgendaViewerScreen> createState() => _AgendaViewerScreenState();
}

class _AgendaViewerScreenState extends State<AgendaViewerScreen> {
  Uint8List? _pdfBytes; // Store the PDF bytes separately
  bool _isPdfLoading = false;
  String? _pdfError;
  bool _hasInitiatedLoad = false;

  @override
  void initState() {
    super.initState();
    if (!_hasInitiatedLoad) {
      _hasInitiatedLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isPdfLoading && _pdfBytes == null) {
          _loadPdfFromUrl(widget.agendaUrl);
        }
      });
    }
  }

  Future<void> _loadPdfFromUrl(String url) async {
    if (!mounted || _isPdfLoading || _pdfBytes != null) return;
    setState(() {
      _isPdfLoading = true;
      _pdfError = null;
    });

    try {
      print('Loading PDF from URL: $url');
      
      // Extract file path from Firebase Storage URL
      String? filePath;
      if (url.contains('storage.googleapis.com')) {
        // Format: https://storage.googleapis.com/PROJECT_ID.firebasestorage.app/PATH
        Uri uri = Uri.parse(url);
        // Skip the first segment (bucket name) and join the rest
        if (uri.pathSegments.length > 1) {
          filePath = uri.pathSegments.skip(1).join('/');
        }
      } else if (url.contains('firebaseapp.com')) {
        // Format: https://PROJECT_ID.firebaseapp.com/PATH
        Uri uri = Uri.parse(url);
        filePath = uri.pathSegments.join('/');
      } else if (url.startsWith('gs://')) {
        // Format: gs://BUCKET_NAME/PATH
        filePath = url.split('/').skip(2).join('/');
      }

      if (filePath == null) {
        throw Exception('Could not extract file path from URL');
      }

      print('Extracted file path: $filePath');

      // Try Firebase Storage SDK first
      try {
        final storageRef = FirebaseStorage.instance.ref().child(filePath);
        print('Firebase Storage reference: $storageRef');
        
        final bytes = await storageRef.getData();
        if (bytes != null) {
          print('PDF downloaded successfully via Firebase SDK, size: ${bytes.length} bytes');
          _loadPdfFromBytes(bytes);
          return;
        }
      } catch (e) {
        print('Firebase SDK failed: $e. Trying HTTP fallback method...');
      }

      // Fallback: Try HTTP with ?alt=media
      try {
        final downloadUrl = 'https://storage.googleapis.com/toastmasters-daily.firebasestorage.app/$filePath?alt=media';
        print('Trying HTTP fallback with URL: $downloadUrl');
        
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          print('HTTP fallback successful, size: ${response.bodyBytes.length} bytes');
          _loadPdfFromBytes(response.bodyBytes);
          return;
        } else {
          print('HTTP fallback failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('HTTP fallback also failed: $e');
      }

      // Final fallback: Try original URL with ?alt=media
      try {
        final altMediaUrl = '$url?alt=media';
        print('Trying final fallback with URL: $altMediaUrl');
        
        final response = await http.get(Uri.parse(altMediaUrl));
        if (response.statusCode == 200) {
          print('Final fallback successful, size: ${response.bodyBytes.length} bytes');
          _loadPdfFromBytes(response.bodyBytes);
          return;
        } else {
          print('Final fallback failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('Final fallback also failed: $e');
      }

      throw Exception('All download methods failed');
      
    } catch (e) {
      print('PDF loading error: $e');
      if (!mounted) return;
      setState(() {
        _pdfError = e.toString();
        _isPdfLoading = false;
      });
    }
  }

  void _loadPdfFromBytes(Uint8List bytes) async {
    if (!mounted) return;
    setState(() {
      _pdfBytes = bytes; // Store the bytes for the viewer
      _isPdfLoading = false;
      _pdfError = null;
    });
  }

  Widget _buildWebPdfViewer(String url) {
    if (_isPdfLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[300]!, width: 0.1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading PDF...'),
            ],
          ),
        ),
      );
    }

    if (_pdfError != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[300]!, width: 0.1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red[600], size: 48),
              const SizedBox(height: 16),
              Text(
                'PDF Loading Error',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pdfError!,
                style: TextStyle(color: Colors.red[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadPdfFromUrl(url),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes != null) {
      print('Displaying PDF viewer with bytes, size: ${_pdfBytes!.length}');
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!, width: 0.1),
        ),
        child: PdfViewer.openData(
          _pdfBytes!,
          params: PdfViewerParams(
            pageNumber: 1,
            minScale: 0.5,
            maxScale: 3.0,
          ),
        ),
      );
    }

    // Fallback if no document
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!, width: 0.1),
      ),
      child: const Center(
        child: Text('No PDF loaded'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // PDF Viewer
            Positioned.fill(
              child: _buildWebPdfViewer(widget.agendaUrl),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  color: const Color(0xFF212121),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

