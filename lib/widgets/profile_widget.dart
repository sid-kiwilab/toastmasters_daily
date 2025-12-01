import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:toastmasters_daily/providers/auth_provider.dart' as app_auth;

// Web-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ProfileWidget extends StatefulWidget {
  final Function(bool isSubscriptionActive) onSubscriptionStatusChanged;

  const ProfileWidget({
    super.key,
    required this.onSubscriptionStatusChanged,
  });

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  // Subscription state
  String? _subscriptionStatus; // 'active' or 'inactive' or null
  DateTime? _trialEndDate; // If exists, trial was used
  bool? _subscriptionCancelAtPeriodEnd; // If true, subscription is scheduled to cancel
  DateTime? _subscriptionCurrentPeriodEnd; // When the subscription period ends
  StreamSubscription<DocumentSnapshot>? _subscriptionSubscription;
  bool _isSubscriptionDataLoaded = false; // Track if subscription data has been loaded
  
  bool _isSendingVerificationEmail = false;
  bool _isStartingTrial = false;
  bool _isCreatingCheckoutSession = false;
  bool _isCancellingSubscription = false;
  bool _isResumingSubscription = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSubscriptionListener();
    });
  }

  @override
  void dispose() {
    _subscriptionSubscription?.cancel();
    super.dispose();
  }

  void _setupSubscriptionListener() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final userId = authProvider.currentUser!.uid;
    
    _subscriptionSubscription?.cancel();
    _subscriptionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final subscription = data['subscription'] as String?;
        final trialEndDate = data['trial_end_date'] as Timestamp?;
        final cancelAtPeriodEnd = data['subscription_cancel_at_period_end'] as bool?;
        final currentPeriodEnd = data['subscription_current_period_end'] as Timestamp?;
        setState(() {
          _subscriptionStatus = subscription;
          _trialEndDate = trialEndDate?.toDate();
          _subscriptionCancelAtPeriodEnd = cancelAtPeriodEnd;
          _subscriptionCurrentPeriodEnd = currentPeriodEnd?.toDate();
          _isSubscriptionDataLoaded = true; // Mark as loaded after first snapshot
        });
        
        // Notify parent about subscription status
        final isActive = _subscriptionStatus == 'active' || 
            (_trialEndDate != null && _trialEndDate!.isAfter(DateTime.now()));
        widget.onSubscriptionStatusChanged(isActive);
      } else {
        setState(() {
          _subscriptionStatus = null;
          _trialEndDate = null;
          _isSubscriptionDataLoaded = true; // Mark as loaded even if document doesn't exist
        });
        widget.onSubscriptionStatusChanged(false);
      }
    }, onError: (error) {
      print('Error listening to subscription status: $error');
    });
  }

  Future<void> _subscribe(BuildContext context) async {
    // Check if this is a trial start (no trial_end_date exists)
    final isTrialStart = _trialEndDate == null;
    
    if (isTrialStart) {
      // Show trial confirmation dialog
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Start Free Trial',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your trial will start for 30 days.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF212121),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'After the trial period ends, you can continue using the service for \$5 USD per month.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isStartingTrial ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6366F1), // Indigo
                          Color(0xFF8B5CF6), // Purple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: _isStartingTrial
                          ? null
                          : () async {
                          setDialogState(() {
                            _isStartingTrial = true;
                          });
                          
                          // Start trial - set trial_end_date to 30 days from now
                          final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                          if (authProvider.currentUser == null) {
                            if (mounted) {
                              setState(() {
                                _isStartingTrial = false;
                              });
                              Navigator.of(dialogContext).pop(false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User not authenticated'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          
                          try {
                            // Double-check: Verify trial_end_date doesn't already exist
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(authProvider.currentUser!.uid)
                                .get();
                            
                            if (userDoc.exists) {
                              final userData = userDoc.data();
                              final existingTrialEndDate = userData?['trial_end_date'];
                              
                              if (existingTrialEndDate != null) {
                                // Trial already exists, don't allow starting another one
                                if (mounted) {
                                  setState(() {
                                    _isStartingTrial = false;
                                  });
                                  Navigator.of(dialogContext).pop(false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trial has already been started. You cannot start another trial.'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            
                            // Set trial_end_date to 30 days from now
                            final trialEndDate = DateTime.now().add(const Duration(days: 30));
                            
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(authProvider.currentUser!.uid)
                                .set({
                              'trial_end_date': Timestamp.fromDate(trialEndDate),
                            }, SetOptions(merge: true));
                            
                            if (mounted) {
                              setState(() {
                                _isStartingTrial = false;
                              });
                              Navigator.of(dialogContext).pop(true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Trial started successfully! Your 30-day trial has begun.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error starting trial: $e');
                            if (mounted) {
                              setState(() {
                                _isStartingTrial = false;
                              });
                              Navigator.of(dialogContext).pop(false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to start trial: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: _isStartingTrial
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Start Trial',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      if (shouldProceed != true) {
        setState(() {
          _isStartingTrial = false;
        });
        return; // User cancelled or error occurred
      }
    } else {
      // Regular subscription flow - create checkout session
      const String price_id = 'price_1SVPGsCFYmZ3GbaT4UO5fRvQ';
      
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isCreatingCheckoutSession = true;
      });

      // Get base URL for web
      final base_url = kIsWeb ? Uri.base.origin : null;

      try {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('create_checkout_session');
        final result = await callable.call({
          'price_id': price_id,
          'user_id': authProvider.currentUser!.uid,
          'email': authProvider.currentUser!.email,
          'base_url': base_url,
        });

        final session_url = result.data['url'] as String?;
        
        if (mounted) {
          setState(() {
            _isCreatingCheckoutSession = false;
          });
        }
        
        if (session_url != null && session_url.isNotEmpty) {
          if (kIsWeb) {
            // Use anchor element click method - most reliable, simulates user click
            // This approach is trusted by browsers and won't be blocked
            final anchor = html.AnchorElement(href: session_url)
              ..target = '_blank'
              ..rel = 'noopener noreferrer'
              ..style.display = 'none';
            html.document.body?.append(anchor);
            anchor.click();
            // Remove after a brief delay to ensure click is processed
            Future.delayed(const Duration(milliseconds: 100), () {
              anchor.remove();
            });
          } else {
            final uri = Uri.parse(session_url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open checkout page'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create checkout session'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Error creating checkout session: $e');
        if (mounted) {
          setState(() {
            _isCreatingCheckoutSession = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create checkout session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _stopSubscription(BuildContext context) async {
    // Show confirmation dialog to cancel auto-renewal
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cancel Subscription',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF212121),
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel auto-renewal?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your subscription will remain active until the end of the current billing period. After that, it will not renew automatically.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isCancellingSubscription ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Keep',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isCancellingSubscription
                      ? null
                      : () async {
                      setState(() {
                        _isCancellingSubscription = true;
                      });
                      setDialogState(() {}); // Rebuild dialog

                      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                      if (authProvider.currentUser == null) {
                        if (mounted) {
                          setState(() { _isCancellingSubscription = false; });
                          Navigator.of(dialogContext).pop(false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User not authenticated'), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }

                      try {
                        final functions = FirebaseFunctions.instance;
                        final callable = functions.httpsCallable('cancel_subscription');
                        await callable.call();

                        if (mounted) {
                          setState(() { _isCancellingSubscription = false; });
                          Navigator.of(dialogContext).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Auto-renewal canceled. Subscription will end at the current period.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error canceling subscription: $e');
                        if (mounted) {
                          setState(() { _isCancellingSubscription = false; });
                          Navigator.of(dialogContext).pop(false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to cancel auto-renewal: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: _isCancellingSubscription
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldCancel != true) {
      setState(() { _isCancellingSubscription = false; });
    }
  }

  Future<void> _resumeSubscription(BuildContext context) async {
    // Show confirmation dialog to resume auto-renewal
    final shouldResume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Resume Subscription',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF212121),
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resume automatic subscription renewal?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your subscription will automatically renew at the end of each billing period.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isResumingSubscription ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1), // Indigo
                      Color(0xFF8B5CF6), // Purple
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isResumingSubscription
                      ? null
                      : () async {
                      setState(() {
                        _isResumingSubscription = true;
                      });
                      setDialogState(() {}); // Rebuild dialog

                      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                      if (authProvider.currentUser == null) {
                        if (mounted) {
                          setState(() { _isResumingSubscription = false; });
                          Navigator.of(dialogContext).pop(false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User not authenticated'), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }

                      try {
                        final functions = FirebaseFunctions.instance;
                        final callable = functions.httpsCallable('resume_subscription');
                        await callable.call();

                        if (mounted) {
                          setState(() { _isResumingSubscription = false; });
                          Navigator.of(dialogContext).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Auto-renewal resumed successfully'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error resuming subscription: $e');
                        if (mounted) {
                          setState(() { _isResumingSubscription = false; });
                          Navigator.of(dialogContext).pop(false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to resume auto-renewal: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: _isResumingSubscription
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Resume',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldResume != true) {
      setState(() { _isResumingSubscription = false; });
    }
  }

  Future<void> _sendVerificationEmail(BuildContext context, app_auth.AuthProvider authProvider) async {
    setState(() {
      _isSendingVerificationEmail = true;
    });

    try {
      final success = await authProvider.sendVerificationEmail();
      if (context.mounted) {
        setState(() {
          _isSendingVerificationEmail = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent successfully! Please check your inbox.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send verification email. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        setState(() {
          _isSendingVerificationEmail = false;
        });
        String errorMessage;
        if (e.code == 'too-many-requests') {
          errorMessage = 'We have blocked all requests from this device due to unusual activity. Please wait and try again later.';
        } else {
          errorMessage = e.message ?? 'Failed to send verification email. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isSendingVerificationEmail = false;
        });
        // Check if error string contains the too-many-requests message
        final errorString = e.toString();
        String errorMessage;
        if (errorString.contains('too-many-requests')) {
          errorMessage = 'We have blocked all requests from this device due to unusual activity. Please wait and try again later.';
        } else {
          errorMessage = 'Failed to send verification email. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Profile',
          'Manage your account information',
        ),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            // Email
            Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, child) {
                final email = authProvider.userEmail ?? 'No email';
                final isVerified = authProvider.isEmailVerified;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE5E7EB),
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
                              Icons.email,
                              size: 22,
                              color: Color(0xFF424242),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isVerified ? Colors.green[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isVerified ? 'Verified' : 'Not verified',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isVerified ? Colors.green[700] : Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!isVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              child: TextButton.icon(
                                onPressed: _isSendingVerificationEmail ? null : () => _sendVerificationEmail(context, authProvider),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: _isSendingVerificationEmail
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                        ),
                                      )
                                    : const Icon(Icons.email, size: 18),
                                label: _isSendingVerificationEmail
                                    ? const SizedBox.shrink()
                                    : const Text(
                                        'Verify',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Subscription button (last item in Profile card)
            Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, child) {
                final isEmailVerified = authProvider.isEmailVerified;
                final isActive = _subscriptionStatus == 'active';
                final hasTrialEndDate = _trialEndDate != null;
                
                // Calculate days remaining in trial or subscription cancellation date
                String subscriptionValue;
                if (_subscriptionCancelAtPeriodEnd == true && _subscriptionCurrentPeriodEnd != null) {
                  // Subscription is scheduled to cancel
                  final cancelDate = _subscriptionCurrentPeriodEnd!;
                  if (cancelDate.isAfter(DateTime.now())) {
                    final monthNames = [
                      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                    ];
                    final formattedDate = '${cancelDate.day} ${monthNames[cancelDate.month - 1]} ${cancelDate.year}';
                    subscriptionValue = 'Cancels $formattedDate';
                  } else {
                    subscriptionValue = 'Cancelled';
                  }
                } else if (isActive) {
                  subscriptionValue = 'Active';
                } else if (hasTrialEndDate && _trialEndDate!.isAfter(DateTime.now())) {
                  final daysRemaining = _trialEndDate!.difference(DateTime.now()).inDays;
                  subscriptionValue = '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left in trial';
                } else if (hasTrialEndDate && !_trialEndDate!.isAfter(DateTime.now())) {
                  subscriptionValue = 'Trial ended. Inactive';
                } else {
                  subscriptionValue = 'Inactive';
                }
                
                // Button is enabled only if subscription data is loaded AND (subscription is active OR email is verified)
                // Also disable if creating checkout session or cancelling/resuming subscription
                final isButtonEnabled = _isSubscriptionDataLoaded && 
                    (isActive || isEmailVerified) && 
                    !_isCreatingCheckoutSession &&
                    !_isCancellingSubscription &&
                    !_isResumingSubscription;
                final buttonText = isActive 
                    ? (_subscriptionCancelAtPeriodEnd == true ? 'Resume Subscription' : 'Stop Subscription')
                    : (hasTrialEndDate ? 'Subscribe' : 'Start Trial');
                
                String tooltipMessage = '';
                if (!_isSubscriptionDataLoaded) {
                  tooltipMessage = 'Loading subscription status...';
                } else if (!isActive && !isEmailVerified) {
                  tooltipMessage = 'Please verify your email to ${hasTrialEndDate ? "subscribe" : "start trial"}';
                }
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE5E7EB),
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
                                  Icons.payment,
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
                                      'Club Subscription',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subscriptionValue,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Tooltip(
                            message: tooltipMessage,
                            child: SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: isButtonEnabled
                                      ? (isActive && _subscriptionCancelAtPeriodEnd != true
                                          ? const LinearGradient(
                                              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                            )
                                          : const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF6366F1), // Indigo
                                                Color(0xFF8B5CF6), // Purple
                                              ],
                                            ))
                                      : null,
                                  color: isButtonEnabled ? null : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: isButtonEnabled
                                      ? () {
                                          if (isActive) {
                                            // Cancel or Resume renewal based on current state
                                            if (_subscriptionCancelAtPeriodEnd == true) {
                                              _resumeSubscription(context);
                                            } else {
                                              _stopSubscription(context);
                                            }
                                          } else {
                                            // Subscribe or Start Trial
                                            _subscribe(context);
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    disabledForegroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: (_isCreatingCheckoutSession || _isCancellingSubscription || _isResumingSubscription)
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          buttonText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

