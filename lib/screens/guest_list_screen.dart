import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  StreamSubscription<QuerySnapshot>? _guestsSubscription;
  List<Map<String, dynamic>> _guests = [];
  Set<String> _selectedGuestIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _setupGuestsListener();
  }

  @override
  void dispose() {
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
        .limit(100) // Limit to most recent 100 guests
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      setState(() {
        _guests = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'comments': data['comments'] ?? '',
            'created_at': data['created_at'],
          };
        }).toList();
      });
    }, onError: (error) {
      print('Error loading guests: $error');
    });
  }

  List<Map<String, dynamic>> get _displayedGuests {
    return _guests;
  }

  Map<String, List<Map<String, dynamic>>> _groupGuestsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final guest in _displayedGuests) {
      final createdAt = guest['created_at'] as Timestamp?;
      String dateKey;
      
      if (createdAt != null) {
        final date = createdAt.toDate();
        dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else {
        dateKey = 'Unknown';
      }
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(guest);
    }
    
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'Unknown') return 1;
      if (b == 'Unknown') return -1;
      return b.compareTo(a);
    });
    
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  String _formatDateHeader(String dateKey) {
    if (dateKey == 'Unknown') return 'Unknown Date';
    
    try {
      final parts = dateKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      if (dateOnly == today) {
        return 'Today';
      } else if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[month - 1]} ${day}, ${year}';
      }
    } catch (e) {
      return dateKey;
    }
  }

  Future<void> _deleteSelectedGuests() async {
    if (_selectedGuestIds.isEmpty) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final count = _selectedGuestIds.length;
    final guestIdsToDelete = _selectedGuestIds.toList();
    
    setState(() {
      _isDeleting = true;
    });
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final guestId in guestIdsToDelete) {
        final guestRef = FirebaseFirestore.instance
            .collection('users')
            .doc(authProvider.currentUser!.uid)
            .collection('guests')
            .doc(guestId);
        batch.delete(guestRef);
      }
      
      await batch.commit();
      
      setState(() {
        _selectedGuestIds.clear();
        _isDeleting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count ${count == 1 ? 'guest' : 'guests'} deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting guests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleGuestSelection(String guestId) {
    setState(() {
      if (_selectedGuestIds.contains(guestId)) {
        _selectedGuestIds.remove(guestId);
      } else {
        _selectedGuestIds.add(guestId);
      }
    });
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedGuests = _groupGuestsByDate();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Guests'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
        actions: [
          if (_selectedGuestIds.isNotEmpty) ...[
            InkWell(
              onTap: _isDeleting ? null : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Guests'),
                    content: Text(
                      'Are you sure you want to delete ${_selectedGuestIds.length} ${_selectedGuestIds.length == 1 ? 'guest' : 'guests'}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await _deleteSelectedGuests();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isDeleting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF424242)),
                        ),
                      )
                    else
                      const Icon(Icons.delete_outline, size: 18, color: Color(0xFF424242)),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isDeleting ? Colors.grey[400] : const Color(0xFF424242),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: _guests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No guests yet',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guests who enter their information will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...groupedGuests.entries.map((entry) {
                        final dayCount = entry.value.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12, top: 8),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDateHeader(entry.key),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($dayCount ${dayCount == 1 ? 'guest' : 'guests'})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...entry.value.map((guest) => _buildGuestCard(guest)),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildGuestCard(Map<String, dynamic> guest) {
    final guestId = guest['id'] as String;
    final isSelected = _selectedGuestIds.contains(guestId);
    final createdAt = guest['created_at'] as Timestamp?;
    final dateStr = createdAt != null
        ? _formatTime(createdAt.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () => _toggleGuestSelection(guestId),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF424242) : Colors.white,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest['name'] ?? 'No name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guest['email'] ?? 'No email',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (guest['phone'] != null && guest['phone'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      guest['phone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                  if (guest['comments'] != null && guest['comments'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              guest['comments'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

