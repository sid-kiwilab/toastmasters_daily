import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'dart:async';
import '../providers/auth_provider.dart';

// Web-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';

class MyClubWidget extends StatefulWidget {
  const MyClubWidget({super.key});

  @override
  State<MyClubWidget> createState() => _MyClubWidgetState();
}

class _MyClubWidgetState extends State<MyClubWidget> {
  // Club name state
  String? _clubName;
  final TextEditingController _clubNameController = TextEditingController();
  bool _isSavingClubName = false;
  
  // Club info state
  String? _clubInfo;
  final TextEditingController _clubInfoController = TextEditingController();
  bool _isSavingClubInfo = false;
  
  // Club location state
  String? _clubLocation;
  final TextEditingController _clubLocationController = TextEditingController();
  bool _isSavingClubLocation = false;
  
  // Club code state
  String? _clubCode; // Display as string, but stored as number in Firestore
  StreamSubscription<DocumentSnapshot>? _clubCodeSubscription;
  bool _isLoadingClubCode = false;
  bool _isRegeneratingClubCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadClubCode();
    });
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _clubInfoController.dispose();
    _clubLocationController.dispose();
    _clubCodeSubscription?.cancel();
    super.dispose();
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
          _clubLocation = data['club_location'] as String?;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
    }
  }

  void _setupClubCodeListener(String userId) {
    _clubCodeSubscription?.cancel();
    _clubCodeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      if (snapshot.exists) {
        final data = snapshot.data();
        final clubCodeValue = data?['club_code'] as int?;
        
        if (clubCodeValue != null) {
          final clubCodeString = clubCodeValue.toString();
          
          if (clubCodeString != _clubCode) {
            setState(() {
              _clubCode = clubCodeString;
            });
          }
        } else {
          setState(() {
            _clubCode = null;
          });
        }
      }
    }, onError: (error) {
      print('Error in club code listener: $error');
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
      
      // Load club_code from user document (should always exist after user creation)
      if (userDocSnap.exists) {
        final codeValue = userDocSnap.data()?['club_code'] as int?;
        if (codeValue != null) {
          clubCode = codeValue.toString();
        }
      }
      
      if (clubCode == null) {
        print('Warning: Club code not found for user $userId. It should have been created on signup.');
      }
      
      if (mounted) {
        setState(() {
          _clubCode = clubCode;
          _isLoadingClubCode = false;
        });
        
        // Set up real-time listener for club_code changes
        _setupClubCodeListener(userId);
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
      // Generate unique 8-digit club code before transaction
      String newClubCode;
      int attempts = 0;
      const maxAttempts = 20;
      final random = Random();
      
      do {
        // Generate random 8-digit number (10000000 to 99999999)
        final codeValue = 10000000 + random.nextInt(90000000);
        newClubCode = codeValue.toString();
        
        // Check if code exists as document ID in club_codes collection
        final existingCodeSnap = await db.collection('club_codes').doc(newClubCode).get();
        
        // Also check if any user already has this club_code value (as number)
        final existingUserWithCode = await db.collection('users')
            .where('club_code', isEqualTo: int.parse(newClubCode))
            .limit(1)
            .get();
        
        if (!existingCodeSnap.exists && existingUserWithCode.docs.isEmpty) {
          break; // Code is available
        }
        
        attempts++;
        if (attempts >= maxAttempts) {
          throw Exception('Failed to generate unique club code after $maxAttempts attempts');
        }
      } while (attempts < maxAttempts);
      
      // Now run transaction - ALL READS FIRST, THEN ALL WRITES
      await db.runTransaction((transaction) async {
        final userDocRef = db.collection('users').doc(userId);
        final userDocSnap = await transaction.get(userDocRef);
        
        String? oldClubCode;
        if (userDocSnap.exists) {
          final oldCodeValue = userDocSnap.data()?['club_code'] as int?;
          if (oldCodeValue != null) {
            oldClubCode = oldCodeValue.toString();
          }
        }
        
        // Read old club_code document if it exists
        DocumentSnapshot? oldClubCodeSnap;
        if (oldClubCode != null && oldClubCode.isNotEmpty) {
          final oldClubCodeRef = db.collection('club_codes').doc(oldClubCode);
          oldClubCodeSnap = await transaction.get(oldClubCodeRef);
        }
        
        // Read new club_code document to verify it doesn't exist
        final newClubCodeRef = db.collection('club_codes').doc(newClubCode);
        final newClubCodeSnap = await transaction.get(newClubCodeRef);
        
        if (newClubCodeSnap.exists) {
          throw Exception('Club code collision detected during transaction');
        }
        
        // NOW DO ALL WRITES (after all reads)
        // Delete old club_codes document if it exists
        if (oldClubCodeSnap != null && oldClubCodeSnap.exists) {
          transaction.delete(db.collection('club_codes').doc(oldClubCode));
        }
        
        // Create new club_codes document with 8-digit code
        transaction.set(newClubCodeRef, {'uid': userId});
        
        // Update user document with new 8-digit club_code as number
        transaction.set(userDocRef, {'club_code': int.parse(newClubCode)}, SetOptions(merge: true));
      });
      
      // Listener will automatically update _clubCode, no need to reload
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
        title: const Text('⚠️ Regenerate Club Code'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const Text(
            'WARNING: Generating a new club code will immediately invalidate your current code!\n\n'
            'The old code will stop working instantly, and anyone trying to use it will be unable to access your club.\n\n'
            'You MUST update ALL physical QR codes that have been printed, displayed, or shared. This includes:\n'
            '• Printed posters and flyers\n'
            '• Digital displays\n'
            '• Shared links and bookmarks\n'
            '• Any other materials with the old code\n\n'
            'Are you absolutely sure you want to proceed?',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showFinalConfirmationDialog();
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

  void _showFinalConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const Text(
            'Are you absolutely sure you want to regenerate your club code? This action cannot be undone.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
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
            child: const Text('Yes, Regenerate'),
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
                const Text('Club Name'),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isSavingClubName ? null : () => Navigator.of(dialogContext).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: _clubNameController,
                autofocus: true,
                enabled: !_isSavingClubName,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: 'Enter club name...',
                  border: OutlineInputBorder(),
                  counterText: '',
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
              width: 500,
              child: TextField(
                controller: _clubInfoController,
                autofocus: true,
                enabled: !_isSavingClubInfo,
                maxLines: 12,
                minLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Add information about your club...',
                  border: OutlineInputBorder(),
                  counterText: '',
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

  Future<void> _saveClubLocation(String newValue) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authProvider.currentUser!.uid)
          .set({
        'club_location': newValue.isEmpty ? '' : newValue,
      }, SetOptions(merge: true));
      
      if (mounted) {
        setState(() {
          _clubLocation = newValue.isEmpty ? null : newValue;
          _isSavingClubLocation = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue.isEmpty ? 'Club location cleared' : 'Club location saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingClubLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving club location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClubLocationDialog() {
    _clubLocationController.text = _clubLocation ?? '';
    _isSavingClubLocation = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Club Location'),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isSavingClubLocation ? null : () => Navigator.of(dialogContext).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: _clubLocationController,
                autofocus: true,
                enabled: !_isSavingClubLocation,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Enter club location...',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSavingClubLocation ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isSavingClubLocation ? null : () async {
                  setState(() {
                    _isSavingClubLocation = true;
                  });
                  setDialogState(() {});
                  
                  final newValue = _clubLocationController.text.trim();
                  await _saveClubLocation(newValue);
                },
                child: _isSavingClubLocation
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
      if (mounted && _isSavingClubLocation) {
        setState(() {
          _isSavingClubLocation = false;
        });
      }
    });
  }

  void _showGuestsScreen() {
    Navigator.of(context).pushNamed('/guest-list');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'My Club',
          'Manage your club information',
        ),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            _buildItem(
              icon: Icons.groups,
              label: 'Club Name',
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
            _buildItem(
              icon: Icons.location_on,
              label: 'Club Location',
              value: _clubLocation ?? 'Not set',
              onTap: _showClubLocationDialog,
            ),
            // Club Code with buttons
            _buildClubCodeItem(),
            // Guests button
            _buildGuestsItem(),
          ],
        ),
      ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          'Club Code',
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
              // QR Code display - updates in real-time
              if (_clubCode != null && !_isLoadingClubCode) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: '${Uri.base.origin}/clubs/$_clubCode',
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      errorStateBuilder: (context, error) {
                        return Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.grey[600],
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'QR Code Error',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Visit My Club button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/clubs/$_clubCode');
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Visit My Club'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
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
          onTap: _showGuestsScreen,
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

