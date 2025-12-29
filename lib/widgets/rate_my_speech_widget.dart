import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class RateMySpeechWidget extends StatelessWidget {
  const RateMySpeechWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        final isClassic = themeProvider.currentTheme == AppThemeType.toastmasters;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 24, bottom: 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Rate my speech',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212121),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: isClassic ? const Color(0xFF772432) : const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildHeroSection(context, colors, isClassic),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection(BuildContext context, AppThemeColors colors, bool isClassic) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        if (isMobile) {
          return _buildMobileLayout(context, colors, isClassic);
        }
        return _buildDesktopLayout(context, colors, isClassic);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.bannerShadow.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              // Background gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors.bannerGradient,
                    ),
                  ),
                ),
              ),
              // Decorative elements
              _buildDecorativeElements(colors),
              // Content
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left side - Visual
                    Expanded(
                      flex: 5,
                      child: _buildVisualSide(colors),
                    ),
                    // Right side - Content
                    Expanded(
                      flex: 6,
                      child: _buildContentSide(context, colors, isClassic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.bannerShadow.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors.bannerGradient,
                    ),
                  ),
                ),
              ),
              _buildDecorativeElements(colors),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVisualIcon(colors, 80),
                    const SizedBox(height: 24),
                    _buildContentText(colors),
                    const SizedBox(height: 24),
                    _buildActionButton(context, colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualSide(AppThemeColors colors) {
    return Stack(
      children: [
        // Large icon with glow
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.mic_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
        // Floating elements
        Positioned(
          top: 60,
          right: 40,
          child: _buildFloatingIcon(Icons.graphic_eq, colors),
        ),
        Positioned(
          bottom: 80,
          left: 50,
          child: _buildFloatingIcon(Icons.volume_up, colors),
        ),
        Positioned(
          top: 120,
          left: 30,
          child: _buildFloatingIcon(Icons.analytics, colors),
        ),
      ],
    );
  }

  Widget _buildVisualIcon(AppThemeColors colors, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.mic_rounded,
          size: size * 0.5,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white.withOpacity(0.9),
        size: 24,
      ),
    );
  }

  Widget _buildContentSide(BuildContext context, AppThemeColors colors, bool isClassic) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContentText(colors),
            const SizedBox(height: 24),
            _buildActionButton(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildContentText(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get instant AI-powered',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'speech evaluation',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Upload your video and receive detailed feedback on vocal variety, clarity, filler words, pacing, and more.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.9),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        // Feature list
        _buildFeatureList(colors),
      ],
    );
  }

  Widget _buildFeatureList(AppThemeColors colors) {
    final features = [
      {'icon': Icons.graphic_eq, 'text': 'Vocal Variety'},
      {'icon': Icons.volume_up, 'text': 'Voice Clarity'},
      {'icon': Icons.chat_bubble_outline, 'text': 'Filler Words'},
      {'icon': Icons.speed, 'text': 'Pacing Analysis'},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: features.map((feature) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                feature['icon'] as IconData,
                size: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 8),
              Text(
                feature['text'] as String,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context, AppThemeColors colors) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleUploadSpeech(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    color: colors.bannerGradient[0],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Upload Speech',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.bannerGradient[0],
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.bannerGradient[0],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUploadSpeech(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn || authProvider.userId == null) {
      // Only members can upload videos
      Navigator.of(context).pushNamed('/member-login');
      return;
    }

    dynamic result2;
    try {
      // Pick video file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      
      // Validate file type
      final allowedExtensions = ['mp4', 'webm', 'mov', 'avi'];
      if (file.extension == null || !allowedExtensions.contains(file.extension!.toLowerCase())) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only video files are allowed (mp4, webm, mov, avi)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get file bytes
      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access file data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show uploading message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting upload URL...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get presigned URL from Firebase Function
      final functions = FirebaseFunctions.instance;
      final contentType = _getContentType(file.extension ?? 'mp4');
      
      dynamic result2;
      result2 = await functions.httpsCallable('get_speech_upload_url').call({
        'fileName': file.name,
        'contentType': contentType,
      });

      if (!result2.data['success']) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result2.data['error'] ?? 'Failed to get upload URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final uploadUrl = result2.data['uploadUrl'] as String;
      final videoId = result2.data['videoId'] as String?;
      final publicUrl = result2.data['publicUrl'] as String?;

      // Update status to uploading
      if (videoId != null) {
        try {
          await functions.httpsCallable('update_video_status').call({
            'videoId': videoId,
            'status': 'uploading',
          });
        } catch (e) {
          // Log but don't fail the upload if status update fails
          print('Failed to update status to uploading: $e');
        }
      }

      // Upload directly to R2
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading video...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Convert bytes to Uint8List for web compatibility
      final uploadBytes = Uint8List.fromList(bytes);
      
      try {
        final response = await http.put(
          Uri.parse(uploadUrl),
          body: uploadBytes,
          headers: {
            'Content-Type': contentType,
          },
        ).timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            throw Exception('Upload timeout - file may be too large');
          },
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          // Atomically update status to uploaded (only if currently uploading)
          if (videoId != null) {
            try {
              final statusResult = await functions.httpsCallable('complete_video_upload').call({
                'videoId': videoId,
              });
              if (!statusResult.data['success']) {
                print('Failed to update status to uploaded: ${statusResult.data['error']}');
                // Try fallback to regular status update
                try {
                  await functions.httpsCallable('update_video_status').call({
                    'videoId': videoId,
                    'status': 'uploaded',
                  });
                } catch (e) {
                  print('Fallback status update also failed: $e');
                }
              }
            } catch (e) {
              // Log but don't fail if status update fails - upload succeeded
              print('Failed to update status to uploaded: $e');
              // Try fallback
              try {
                await functions.httpsCallable('update_video_status').call({
                  'videoId': videoId,
                  'status': 'uploaded',
                });
              } catch (fallbackError) {
                print('Fallback status update failed: $fallbackError');
              }
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video uploaded successfully!${publicUrl != null ? '\nPublic URL: $publicUrl' : ''}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Update status to failed if we have videoId
          if (videoId != null) {
            try {
              await functions.httpsCallable('update_video_status').call({
                'videoId': videoId,
                'status': 'failed',
              });
            } catch (e) {
              print('Failed to update status to failed: $e');
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${response.statusCode} - ${response.body}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } on http.ClientException catch (e) {
        // Update status to failed if we have videoId
        if (videoId != null) {
          try {
            await functions.httpsCallable('update_video_status').call({
              'videoId': videoId,
              'status': 'failed',
            });
          } catch (updateError) {
            print('Failed to update status to failed: $updateError');
          }
        }

        // Handle network/CORS errors
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Network error: ${e.message}. This may be a CORS issue. Please check R2 bucket CORS settings.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        rethrow;
      }
    } catch (e) {
      // Update status to failed if we have videoId (only if we got past getting the URL)
      // Note: videoId is only set if we successfully got the upload URL
      try {
        final videoIdForError = (result2 as dynamic)?.data?['videoId'] as String?;
        if (videoIdForError != null) {
          try {
            await FirebaseFunctions.instance.httpsCallable('update_video_status').call({
              'videoId': videoIdForError,
              'status': 'failed',
            });
          } catch (updateError) {
            print('Failed to update status to failed: $updateError');
          }
        }
      } catch (_) {
        // Ignore errors when trying to get videoId from result2
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'video/mp4';
    }
  }

  Widget _buildDecorativeElements(AppThemeColors colors) {
    return Stack(
      children: [
        // Large circle
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Medium circle
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Small circles
        Positioned(
          top: 40,
          left: 40,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 60,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }
}

