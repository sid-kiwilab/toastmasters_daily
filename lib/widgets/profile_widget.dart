import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:toastmasters_daily/providers/auth_provider.dart' as app_auth;

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
  StreamSubscription<DocumentSnapshot>? _subscriptionSubscription;
  bool _isSubscriptionDataLoaded = false; // Track if subscription data has been loaded
  
  bool _isSendingVerificationEmail = false;
  bool _isStartingTrial = false;

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
        setState(() {
          _subscriptionStatus = subscription;
          _trialEndDate = trialEndDate?.toDate();
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
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Start Free Trial'),
                  Icon(Icons.info_outline, color: Colors.blue),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your trial will start for 30 days.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'After the trial period ends, you can continue using the service for \$5 USD per month.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isStartingTrial ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: _isStartingTrial
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Start Trial'),
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
      // Regular subscription flow
      // TODO: Implement subscription logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscribe feature coming soon'),
        ),
      );
    }
  }

  Future<void> _stopSubscription(BuildContext context) async {
    // TODO: Implement stop subscription logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stop subscription feature coming soon'),
      ),
    );
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
                        color: const Color(0xFFF5F5F5),
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
                                        fontWeight: FontWeight.w500,
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
                                    color: Color(0xFF757575),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!isVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              child: TextButton(
                                onPressed: _isSendingVerificationEmail ? null : () => _sendVerificationEmail(context, authProvider),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(100, 38),
                                ),
                                child: _isSendingVerificationEmail
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.email, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            'Verify',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
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
                
                // Calculate days remaining in trial
                String subscriptionValue;
                if (isActive) {
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
                final isButtonEnabled = _isSubscriptionDataLoaded && (isActive || isEmailVerified);
                final buttonText = isActive 
                    ? 'Stop' 
                    : (hasTrialEndDate ? 'Subscribe' : 'Start Trial');
                
                String tooltipMessage = '';
                if (!_isSubscriptionDataLoaded) {
                  tooltipMessage = 'Loading subscription status...';
                } else if (!isActive && !isEmailVerified) {
                  tooltipMessage = 'Please verify your email to ${hasTrialEndDate ? "subscribe" : "start trial"}';
                }
                
                return _buildItem(
                  icon: Icons.payment,
                  label: 'Subscription',
                  value: subscriptionValue,
                  onTap: null, // Disable the main tap, use trailing button instead
                  isLast: true, // Remove bottom border to show card's rounded corners
                  trailing: Tooltip(
                    message: tooltipMessage,
                    child: ElevatedButton(
                      onPressed: isButtonEnabled
                          ? () {
                              if (isActive) {
                                // Stop subscription
                                _stopSubscription(context);
                              } else {
                                // Subscribe or Start Trial
                                _subscribe(context);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive 
                            ? Colors.red[600] 
                            : Colors.green[600],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        minimumSize: const Size(80, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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

