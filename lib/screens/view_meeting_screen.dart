import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../providers/view_meeting_provider.dart';
import '../widgets/voting_widget.dart';
import '../widgets/footer_widget.dart';
import 'dart:typed_data';

class ViewMeetingScreen extends StatefulWidget {
  final String meetingId;

  const ViewMeetingScreen({super.key, required this.meetingId});

  @override
  State<ViewMeetingScreen> createState() => _ViewMeetingScreenState();
}

class _ViewMeetingScreenState extends State<ViewMeetingScreen> {
  late ViewMeetingProvider _viewMeetingProvider;
  
  Uint8List? _pdfBytes; // Store the PDF bytes separately
  bool _isPdfLoading = false;
  String? _pdfError;
  
  // Fullscreen agenda state
  bool _showFullscreenAgenda = false;

  @override
  void initState() {
    super.initState();
    _viewMeetingProvider = Provider.of<ViewMeetingProvider>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMeetingData();
    });
  }

  Future<void> _loadMeetingData() async {
    // Reset load attempts for new meeting
    _loadAttempts = 0;
    
    _viewMeetingProvider.initialize(widget.meetingId);
    if (_viewMeetingProvider.meeting != null && 
        _viewMeetingProvider.meeting!.agendaUrl != null) {
      _loadPdfFromUrl(_viewMeetingProvider.meeting!.agendaUrl!);
    }
  }

  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  Future<void> _loadPdfFromUrl(String url) async {
    if (!mounted) return;
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
    // Auto-load PDF if not loaded and not currently loading
    if (_pdfBytes == null && !_isPdfLoading && _pdfError == null && _loadAttempts < _maxLoadAttempts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPdfFromUrl(url);
      });
    }

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


  Widget _buildFullscreenAgenda(String? agendaUrl) {
    if (agendaUrl == null || agendaUrl.isEmpty) {
      return Container();
    }
    
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // PDF Viewer
            Positioned.fill(
              child: _buildWebPdfViewer(agendaUrl),
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
                    setState(() {
                      _showFullscreenAgenda = false;
                    });
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


  String _formatMeetingCode(String meetingId) {
    // Format meeting ID as "1234 5678"
    final cleaned = meetingId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length <= 4) {
      return cleaned;
    }
    final chunks = <String>[];
    for (int i = 0; i < cleaned.length; i += 4) {
      final end = (i + 4 < cleaned.length) ? i + 4 : cleaned.length;
      chunks.add(cleaned.substring(i, end));
    }
    return chunks.join(' ');
  }

  @override
  void dispose() {
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

          if (provider.error != null || provider.meeting == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '👻',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 72,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Nothing lives here...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            );
          }

          final meeting = provider.meeting!;

          // Show fullscreen agenda if requested
          if (_showFullscreenAgenda) {
            return _buildFullscreenAgenda(meeting.agendaUrl);
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Main content
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 24.0 : 40.0,
                          vertical: 32.0,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // Meeting Title
                          Text(
                            meeting.title,
                            style: TextStyle(
                              fontSize: isMobile ? 28 : 32,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212121),
                              letterSpacing: -1,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Meeting Code
                          Text(
                            _formatMeetingCode(widget.meetingId),
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF757575),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Decorative line with Toastmasters colors
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFC41E3A),
                                      Color(0xFF003366),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E0E0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF003366),
                                      Color(0xFFC41E3A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          // Quick Actions Section
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212121),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Action Cards
                          if (meeting.agendaUrl != null && meeting.agendaUrl!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _showFullscreenAgenda = true;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFC41E3A),
                                                Color(0xFF003366),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.description,
                                            size: 28,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'View Agenda',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF212121),
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Open agenda in full screen',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: const Color(0xFF757575),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFF757575),
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          // Voting Card
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 2,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => _VotingScreen(meetingId: widget.meetingId),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFC41E3A),
                                              Color(0xFF003366),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.how_to_vote,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Voting',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF212121),
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Participate in polls and voting',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: const Color(0xFF757575),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFF757575),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                                // Meeting Info Section
                                const SizedBox(height: 40),
                                Text(
                                  'Meeting Info',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF212121),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Role Holder Info Button
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 2,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // TODO: Navigate to role holder info screen
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFC41E3A),
                                                    Color(0xFF003366),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.person_outline,
                                                size: 28,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Role Holder Info',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF212121),
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'View meeting role assignments',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: const Color(0xFF757575),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Color(0xFF757575),
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // New Member Details Button
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 2,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // TODO: Navigate to new member details entry screen
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFC41E3A),
                                                    Color(0xFF003366),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.person_add_outlined,
                                                size: 28,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'New to the Club?',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF212121),
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Enter your details',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: const Color(0xFF757575),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Color(0xFF757575),
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Footer - full width
                        const FooterWidget(),
                      ],
                    ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Voting Screen - Full screen for voting
class _VotingScreen extends StatelessWidget {
  final String meetingId;
  
  const _VotingScreen({required this.meetingId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Voting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    color: const Color(0xFF424242),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Voting Widget
            Expanded(
              child: VotingWidget(meetingId: meetingId),
            ),
          ],
        ),
      ),
    );
  }
}
