import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../providers/view_meeting_provider.dart';
import '../providers/manage_meetings_provider.dart';
import '../utils/theme.dart';
import 'dart:typed_data';

class ViewMeetingScreen extends StatefulWidget {
  final String meetingId;

  const ViewMeetingScreen({super.key, required this.meetingId});

  @override
  State<ViewMeetingScreen> createState() => _ViewMeetingScreenState();
}

class _ViewMeetingScreenState extends State<ViewMeetingScreen> {
  late ViewMeetingProvider _viewMeetingProvider;
  late ManageMeetingsProvider _manageMeetingsProvider;
  
  PdfDocument? _pdfDocument;
  Uint8List? _pdfBytes; // Store the PDF bytes separately
  bool _isPdfLoading = false;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    _viewMeetingProvider = Provider.of<ViewMeetingProvider>(context, listen: false);
    _manageMeetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMeetingData();
    });
  }

  Future<void> _loadMeetingData() async {
    _viewMeetingProvider.initialize(widget.meetingId);
    if (_viewMeetingProvider.meeting != null && 
        _viewMeetingProvider.meeting!.agendaUrl != null) {
      _loadPdfFromUrl(_viewMeetingProvider.meeting!.agendaUrl!);
    }
  }

  Future<void> _loadPdfFromUrl(String url) async {
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
      setState(() {
        _pdfError = e.toString();
        _isPdfLoading = false;
      });
    }
  }

  void _loadPdfFromBytes(Uint8List bytes) async {
    try {
      final document = await PdfDocument.openData(bytes);
      setState(() {
        _pdfDocument = document;
        _pdfBytes = bytes; // Store the bytes for the viewer
        _isPdfLoading = false;
        _pdfError = null;
      });
      
      print('PDF loaded successfully into document, pages: ${document.pageCount}');
    } catch (e) {
      print('Error creating PDF document: $e');
      setState(() {
        _pdfError = 'Error creating PDF document: $e';
        _isPdfLoading = false;
      });
    }
  }

  Widget _buildPdfViewer(String url) {
    if (kIsWeb) {
      return _buildWebPdfViewer(url);
    } else {
      return _buildMobilePdfPlaceholder(url);
    }
  }

  Widget _buildWebPdfViewer(String url) {
    if (_isPdfLoading) {
      return Container(
        width: double.infinity,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
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
        height: 500,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[300]!),
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
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PdfViewer.openData(
            _pdfBytes!,
            params: PdfViewerParams(
              pageNumber: 1,
              minScale: 0.5,
              maxScale: 3.0,
            ),
          ),
        ),
      );
    }

    // Fallback if no document
    return Container(
      width: double.infinity,
      height: 500,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Text('No PDF loaded'),
      ),
    );
  }

  Widget _buildMobilePdfPlaceholder(String url) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Document Ready',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Open in Browser" to view the full PDF',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                url,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pdfDocument?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ViewMeetingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Text('Error: ${provider.error}'),
            );
          }

          final meeting = provider.meeting;
          if (meeting == null) {
            return const Center(child: Text('Meeting not found'));
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    meeting.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${meeting.id}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  if (meeting.agendaUrl != null && meeting.agendaUrl!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '📋 Meeting Agenda',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // PDF Viewer Container
                          _buildPdfViewer(meeting.agendaUrl!),
                          
                          const SizedBox(height: 16),
                          
                          // Load PDF Button (for web)
                          if (kIsWeb) ...[
                            ElevatedButton.icon(
                              onPressed: _pdfDocument == null 
                                ? () => _loadPdfFromUrl(meeting.agendaUrl!)
                                : null,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: Text(_pdfDocument == null ? 'Load PDF' : 'PDF Loaded'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No agenda available for this meeting',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
