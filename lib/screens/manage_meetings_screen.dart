import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/manage_meetings_provider.dart';
import '../dialogs/create_meeting_dialog.dart';
import '../screens/setup_polls_screen.dart';
import '../screens/poll_results_screen.dart';
import '../widgets/footer_widget.dart';
import '../widgets/meetings_list_widget.dart';
import '../widgets/profile_widget.dart';
import '../widgets/app_info_widget.dart';

// Web-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ManageMeetingsScreen extends StatefulWidget {
  const ManageMeetingsScreen({super.key});

  @override
  State<ManageMeetingsScreen> createState() => _ManageMeetingsScreenState();
}

class _ManageMeetingsScreenState extends State<ManageMeetingsScreen> {
  bool _isCreatingMeeting = false;
  Map<String, bool> _uploadingAgendas = {}; // Track upload state for each meeting
  
  // Club name state
  String? _clubName;
  final TextEditingController _clubNameController = TextEditingController();
  bool _isSavingClubName = false;
  
  // Club info state
  String? _clubInfo;
  final TextEditingController _clubInfoController = TextEditingController();
  bool _isSavingClubInfo = false;
  
  // Club code state
  String? _clubCode;
  bool _isLoadingClubCode = false;
  bool _isRegeneratingClubCode = false;
  
  // Subscription status for meetings list
  bool _isSubscriptionActive = false;
  
  // Guests state
  StreamSubscription<QuerySnapshot>? _guestsSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize the meetings provider when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      meetingsProvider.initialize();
      _loadProfileData();
      _loadClubCode();
      _setupGuestsListener();
    });
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _clubInfoController.dispose();
    _guestsSubscription?.cancel();
    super.dispose();
  }

  void _setupGuestsListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final userId = authProvider.currentUser!.uid;
    
    _guestsSubscription?.cancel();
    _guestsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('guests')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      // Guest list is now managed by GuestListScreen
      // This listener is kept for potential future use (e.g., showing guest count)
    }, onError: (error) {
      print('Error loading guests: $error');
    });
  }

  Future<void> _loadProfileData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authProvider.currentUser!.uid)
          .get();
      
      if (mounted && userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _clubName = data['club_name'] as String?;
          _clubInfo = data['club_info'] as String?;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
    }
  }

  void _onSubscriptionStatusChanged(bool isActive) {
    setState(() {
      _isSubscriptionActive = isActive;
    });
  }

  Future<void> _loadClubCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final userId = authProvider.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    
    if (mounted) {
      setState(() {
        _isLoadingClubCode = true;
      });
    }
    
    try {
      final userDocRef = db.collection('users').doc(userId);
      final userDocSnap = await userDocRef.get();
      
      String? clubCode;
      
      // Only load existing club_code from user document
      // Club code should have been created by cloud function on user creation
      if (userDocSnap.exists && userDocSnap.data()?['club_code'] != null) {
        clubCode = userDocSnap.data()!['club_code'] as String;
      } else {
        // Fallback: Check if a club_codes document already exists for this user
        // (This handles edge cases where the cloud function might have failed)
        final clubCodesQuery = await db.collection('club_codes')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();
        
        if (clubCodesQuery.docs.isNotEmpty) {
          // Use existing document ID and sync to user document
          clubCode = clubCodesQuery.docs[0].id;
          await userDocRef.set({'club_code': clubCode}, SetOptions(merge: true));
        } else {
          // Club code should have been created by cloud function on user creation
          print('Warning: Club code not found for user $userId. It should have been created on signup.');
          clubCode = null;
        }
      }
      
      if (mounted) {
        setState(() {
          _clubCode = clubCode;
          _isLoadingClubCode = false;
        });
      }
    } catch (e) {
      print('Error loading club code: $e');
      if (mounted) {
        setState(() {
          _isLoadingClubCode = false;
        });
      }
    }
  }

  Future<void> _regenerateClubCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final userId = authProvider.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    
    if (mounted) {
      setState(() {
        _isRegeneratingClubCode = true;
      });
    }
    
    try {
      await db.runTransaction((transaction) async {
        final userDocRef = db.collection('users').doc(userId);
        final userDocSnap = await transaction.get(userDocRef);
        
        String? oldClubCode;
        if (userDocSnap.exists && userDocSnap.data()?['club_code'] != null) {
          oldClubCode = userDocSnap.data()!['club_code'] as String;
        }
        
        // Delete old club_codes document if it exists
        if (oldClubCode != null && oldClubCode.isNotEmpty) {
          final oldClubCodeRef = db.collection('club_codes').doc(oldClubCode);
          final oldDocSnap = await transaction.get(oldClubCodeRef);
          if (oldDocSnap.exists) {
            transaction.delete(oldClubCodeRef);
          }
        }
        
        // Create new document reference in club_codes collection
        final newClubCodeRef = db.collection('club_codes').doc();
        final newClubCode = newClubCodeRef.id;
        
        // Set both documents in the transaction
        transaction.set(newClubCodeRef, {'uid': userId});
        transaction.set(userDocRef, {'club_code': newClubCode}, SetOptions(merge: true));
      });
      
      // Reload the club code
      await _loadClubCode();
      
      if (mounted) {
        setState(() {
          _isRegeneratingClubCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club code regenerated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error regenerating club code: $e');
      if (mounted) {
        setState(() {
          _isRegeneratingClubCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error regenerating club code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    if (_clubCode == null || _clubCode!.isEmpty) return;
    
    try {
      // Get base URL
      final baseUrl = Uri.base.origin;
      final qrCodeData = '$baseUrl/clubs/$_clubCode';
      
      // Get club name for filename
      String? clubName = _clubName;
      final fileName = clubName != null && clubName.isNotEmpty
          ? 'club-code-${clubName.replaceAll(RegExp(r'[^a-z0-9]'), '-').toLowerCase()}.pdf'
          : 'club-code-$_clubCode.pdf';
      
      // Generate QR code image
      final painter = QrPainter(
        data: qrCodeData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      
      // Render QR code to image
      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      const size = 600.0;
      painter.paint(canvas, const Size(size, size));
      final picture = picRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      
      // Convert to PDF image
      final qrImage = pw.MemoryImage(pngBytes);
      
      // Create PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(50),
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR Code
                pw.Center(
                  child: pw.Image(
                    qrImage,
                    width: 400,
                    height: 400,
                  ),
                ),
                pw.SizedBox(height: 30),
                // Club Name
                if (clubName != null && clubName.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      clubName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      );
      
      // Save/download the PDF
      if (kIsWeb) {
        // For web, download PDF directly
        final pdfBytes = await pdf.save();
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // For mobile, use printing package
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      }
    } catch (e) {
      print('Error downloading QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRegenerateCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Club Code'),
        content: const Text(
          'Are you sure you want to generate a new club code? The old code will no longer work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _regenerateClubCode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveClubName(String newValue) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authProvider.currentUser!.uid)
          .set({
        'club_name': newValue.isEmpty ? '' : newValue,
      }, SetOptions(merge: true));
      
      if (mounted) {
        setState(() {
          _clubName = newValue.isEmpty ? null : newValue;
          _isSavingClubName = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue.isEmpty ? 'Club name cleared' : 'Club name saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingClubName = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving club name. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClubNameDialog() {
    _clubNameController.text = _clubName ?? '';
    _isSavingClubName = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toastmasters Club Name'),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isSavingClubName ? null : () => Navigator.of(dialogContext).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: TextField(
                controller: _clubNameController,
                autofocus: true,
                enabled: !_isSavingClubName,
                decoration: const InputDecoration(
                  hintText: 'Enter club name...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSavingClubName ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isSavingClubName ? null : () async {
                  setState(() {
                    _isSavingClubName = true;
                  });
                  setDialogState(() {});
                  
                  final newValue = _clubNameController.text.trim();
                  await _saveClubName(newValue);
                },
                child: _isSavingClubName
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Reset state when dialog closes
      if (mounted && _isSavingClubName) {
        setState(() {
          _isSavingClubName = false;
        });
      }
    });
  }

  Future<void> _saveClubInfo(String newValue) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authProvider.currentUser!.uid)
          .set({
        'club_info': newValue.isEmpty ? '' : newValue,
      }, SetOptions(merge: true));
      
      if (mounted) {
        setState(() {
          _clubInfo = newValue.isEmpty ? null : newValue;
          _isSavingClubInfo = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue.isEmpty ? 'Club info cleared' : 'Club info saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingClubInfo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving club info. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClubInfoDialog() {
    _clubInfoController.text = _clubInfo ?? '';
    _isSavingClubInfo = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Club Info'),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isSavingClubInfo ? null : () => Navigator.of(dialogContext).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: TextField(
                controller: _clubInfoController,
                autofocus: true,
                enabled: !_isSavingClubInfo,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Add information about your club...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSavingClubInfo ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isSavingClubInfo ? null : () async {
                  setState(() {
                    _isSavingClubInfo = true;
                  });
                  setDialogState(() {});
                  
                  final newValue = _clubInfoController.text.trim();
                  await _saveClubInfo(newValue);
                },
                child: _isSavingClubInfo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Reset state when dialog closes
      if (mounted && _isSavingClubInfo) {
        setState(() {
          _isSavingClubInfo = false;
        });
      }
    });
  }

  Future<void> _createMeeting(BuildContext context, String userId, String title) async {
    try {
      // Set loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = true;
        });
      }

      // Call the Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('create_meeting').call({
        'title': title,
        'creator_id': userId,
      });

      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
      }

      // Check result
      if (result.data['success']) {
        final meeting = result.data['meeting'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting created successfully! ID: ${meeting['id']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh the meetings list
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        meetingsProvider.initialize();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create meeting: ${result.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAgenda(BuildContext context, String meetingId) async {
    try {
      // Pick PDF file from device
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true, // This ensures we get bytes for web compatibility
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      
      // Validate file type
      if (file.extension?.toLowerCase() != 'pdf') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only PDF files are allowed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing and uploading PDF...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get bytes from file (works on both web and mobile)
      List<int> bytes;
      if (file.bytes != null) {
        // Web: use bytes directly
        bytes = file.bytes!;
      } else if (file.path != null) {
        // Mobile: read from file path
        final fileData = File(file.path!);
        bytes = await fileData.readAsBytes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access file data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Convert to base64
      final base64Data = base64Encode(bytes);

      // Set uploading state for the meeting (only when calling Cloud Function)
      if (mounted) {
        setState(() {
          _uploadingAgendas[meetingId] = true;
        });
      }

      // Call the Cloud Function to upload agenda
      final functions = FirebaseFunctions.instance;
      final result2 = await functions.httpsCallable('upload_agenda').call({
        'meetingId': meetingId,
        'fileData': base64Data,
        'fileName': file.name,
      });

      if (result2.data['success']) {
        final agenda = result2.data['agenda'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agenda uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('Agenda uploaded: ${agenda['download_url'] ?? agenda['downloadUrl']}');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload agenda: ${result2.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Clear uploading state for the meeting
      if (mounted) {
        setState(() {
          _uploadingAgendas.remove(meetingId);
        });
      }
    }
  }

  void _showSetupPollsDialog(BuildContext context, Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetupPollsScreen(
          meetingId: meeting.id,
          meetingTitle: meeting.title,
        ),
      ),
    );
  }

  void _showPollResultsDialog(BuildContext context, Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PollResultsScreen(
          meetingId: meeting.id,
          meetingTitle: meeting.title,
        ),
      ),
    );
  }

  Future<void> _deleteMeeting(BuildContext context, Meeting meeting, String meetingId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    try {
      // Call the Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('delete_meeting').call({
        'meeting_id': meetingId,
        'creator_id': authProvider.currentUser!.uid,
      });

      // Check result
      if (result.data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh the meetings list
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        meetingsProvider.initialize();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete meeting: ${result.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow; // Re-throw so dialog can handle it
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait for auth state to be resolved before checking
        if (!authProvider.authStateResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Auth gate: redirect to home if not authenticated
        if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with Base title and logout button - full width
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F0F0), // Same as HeaderWidget
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Base',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/');
                          },
                          icon: const Icon(Icons.home, size: 18),
                          label: const Text(
                            'Home',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main content
                  Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Consumer<ManageMeetingsProvider>(
                      builder: (context, meetingsProvider, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Section
                            ProfileWidget(
                              onSubscriptionStatusChanged: _onSubscriptionStatusChanged,
                            ),
                            const SizedBox(height: 32),
                            
                            // My Club Section
                            _buildSectionHeader(
                              'My Club',
                              'Manage your club information',
                            ),
                            const SizedBox(height: 12),
                            _buildCard(
                              children: [
                                _buildItem(
                                  icon: Icons.groups,
                                  label: 'Toastmasters Club Name',
                                  value: _clubName ?? 'Not set',
                                  onTap: _showClubNameDialog,
                                ),
                                _buildItem(
                                  icon: Icons.info_outline,
                                  label: 'Club Info',
                                  value: _clubInfo != null && _clubInfo!.isNotEmpty
                                      ? (_clubInfo!.length > 50 
                                          ? '${_clubInfo!.substring(0, 50)}...' 
                                          : _clubInfo!)
                                      : 'Not set',
                                  onTap: _showClubInfoDialog,
                                ),
                                // Club Code with buttons
                                _buildClubCodeItem(),
                                // Guests button
                                _buildGuestsItem(),
                              ],
                            ),
                            const SizedBox(height: 32),
                            
                            // Meetings Section
                            MeetingsListWidget(
                              meetings: meetingsProvider.meetings,
                              isCreatingMeeting: _isCreatingMeeting,
                              uploadingAgendas: _uploadingAgendas,
                              isSubscriptionActive: _isSubscriptionActive,
                              hasMoreMeetings: meetingsProvider.hasMoreMeetings,
                              isLoadingMore: meetingsProvider.isLoadingMore,
                              onLoadMore: () {
                                meetingsProvider.loadMoreMeetings();
                              },
                              onCreateMeeting: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => CreateMeetingDialog(
                                    onConfirm: (title) async {
                                      await _createMeeting(context, authProvider.currentUser!.uid, title);
                                    },
                                  ),
                                );
                              },
                              onUploadAgenda: _uploadAgenda,
                              onSetupPolls: _showSetupPollsDialog,
                              onPollResults: _showPollResultsDialog,
                              onDeleteMeeting: _deleteMeeting,
                            ),
                            const SizedBox(height: 32),
                            
                            // App Info Section
                            const AppInfoWidget(),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  const FooterWidget(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }


  Widget _buildClubCodeItem() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code,
                  size: 22,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Club QR Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingClubCode
                          ? 'Loading...'
                          : (_clubCode ?? 'Refresh to load code'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_clubCode != null && !_isLoadingClubCode) ...[
                // Download QR Code button
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  color: const Color(0xFF757575),
                  onPressed: _downloadQRCode,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: 'Download QR code',
                ),
                const SizedBox(width: 12),
                // Regenerate button
                _isRegeneratingClubCode
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF757575)),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        color: const Color(0xFF757575),
                        onPressed: _showRegenerateCodeDialog,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        tooltip: 'Generate new code',
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestsItem() {
    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGuestsScreen(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people,
                    size: 22,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(width: 16),
                                                const Expanded(
                                                  child: Text(
                                                    'Club Guests',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF212121),
                                                    ),
                                                  ),
                                                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF9E9E9E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuestsScreen() {
    Navigator.of(context).pushNamed('/guest-list');
  }



  Widget _buildItem({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: const Color(0xFFF5F5F5),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: const Color(0xFF424242),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212121),
                        ),
                      ),
                      if (value != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF9E9E9E),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

