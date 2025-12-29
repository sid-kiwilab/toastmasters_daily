import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  List<Map<String, dynamic>> _allGuestEntries = []; // All individual entries
  List<Map<String, dynamic>> _uniqueGuests = []; // Grouped by device_id with counts
  Set<String> _selectedEntryIds = {}; // Track selection by entry ID (each entry independently)
  Set<String> _expandedDeviceIds = {}; // Track which guests have expanded attendance lists
  Set<String> _copiedEmails = {}; // Track which emails have been copied (for animation)
  bool _isDeleting = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 50; // Load more entries per page for grouping

  @override
  void initState() {
    super.initState();
    _loadGuests();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200 pixels of bottom
      if (!_isLoadingMore && _hasMore) {
        _loadMoreGuests();
      }
    }
  }

  Future<void> _loadGuests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final userId = authProvider.currentUser!.uid;
    
    setState(() {
      _isLoading = true;
      _allGuestEntries = [];
      _uniqueGuests = [];
      _lastDocument = null;
      _hasMore = true;
    });
    
    try {
      // Query main guest documents: users/{userId}/guests/
      final query = FirebaseFirestore.instance
          .collection('club')
          .doc(userId)
          .collection('guests')
          .orderBy('last_updated', descending: true)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      if (!mounted) return;
      
      // Load all attendances for all guests IN PARALLEL (much faster!)
      final allEntries = <Map<String, dynamic>>[];
      
      // Create all attendance queries in parallel
      final attendanceFutures = snapshot.docs.map((guestDoc) async {
        final guestData = guestDoc.data();
        final deviceId = guestDoc.id;
        final attendances = await guestDoc.reference.collection('attendances').get();
        
        return attendances.docs.map((attDoc) {
          final attData = attDoc.data();
          return {
            'id': '${deviceId}_${attDoc.id}',
            'device_id': deviceId,
            'name': guestData['name'] ?? '',
            'email': guestData['email'] ?? '',
            'phone': guestData['phone'] ?? '',
            'comments': attData['comments'] ?? '',
            'hear_about_us': guestData['hear_about_us'] ?? '',
            'created_at': attData['created_at'],
            'entry_date': attData['entry_date'] ?? attDoc.id,
            'attendance_doc_id': attDoc.id,
            'device_doc_id': deviceId,
          };
        }).toList();
      }).toList();
      
      // Wait for all queries to complete in parallel
      final allAttendanceResults = await Future.wait(attendanceFutures);
      
      // Flatten the results
      for (final entries in allAttendanceResults) {
        allEntries.addAll(entries);
      }
      
      setState(() {
        _allGuestEntries = allEntries;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        
        // Group by device_id and count attendances
        _uniqueGuests = _groupGuestsByDeviceId(_allGuestEntries);
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading guests: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreGuests() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    final userId = authProvider.currentUser!.uid;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // Query next page of main guest documents
      final query = FirebaseFirestore.instance
          .collection('club')
          .doc(userId)
          .collection('guests')
          .orderBy('last_updated', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      if (!mounted) return;
      
      // Load attendances for new guests IN PARALLEL (much faster!)
      // Create all attendance queries in parallel
      final attendanceFutures = snapshot.docs.map((guestDoc) async {
        final guestData = guestDoc.data();
        final deviceId = guestDoc.id;
        final attendances = await guestDoc.reference.collection('attendances').get();
        
        return attendances.docs.map((attDoc) {
          final attData = attDoc.data();
          return {
            'id': '${deviceId}_${attDoc.id}',
            'device_id': deviceId,
            'name': guestData['name'] ?? '',
            'email': guestData['email'] ?? '',
            'phone': guestData['phone'] ?? '',
            'comments': attData['comments'] ?? '',
            'hear_about_us': guestData['hear_about_us'] ?? '',
            'created_at': attData['created_at'],
            'entry_date': attData['entry_date'] ?? attDoc.id,
            'attendance_doc_id': attDoc.id,
            'device_doc_id': deviceId,
          };
        }).toList();
      }).toList();
      
      // Wait for all queries to complete in parallel
      final allAttendanceResults = await Future.wait(attendanceFutures);
      
      // Flatten the results
      final newEntries = <Map<String, dynamic>>[];
      for (final entries in allAttendanceResults) {
        newEntries.addAll(entries);
      }
      
      setState(() {
        _allGuestEntries.addAll(newEntries);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        
        // Re-group all entries by device_id
        _uniqueGuests = _groupGuestsByDeviceId(_allGuestEntries);
        _isLoadingMore = false;
      });
    } catch (error) {
      print('Error loading more guests: $error');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Groups guest entries by device_id and counts attendances
  /// Returns list of unique guests with their most recent info and attendance count
  List<Map<String, dynamic>> _groupGuestsByDeviceId(List<Map<String, dynamic>> entries) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    // Group all entries by device_id
    for (final entry in entries) {
      final deviceId = entry['device_id'] as String? ?? '';
      if (deviceId.isEmpty) continue;
      
      if (!grouped.containsKey(deviceId)) {
        grouped[deviceId] = [];
      }
      grouped[deviceId]!.add(entry);
    }
    
    // Create unique guest list with most recent info and attendance count
    final uniqueGuests = <Map<String, dynamic>>[];
    
    for (final entry in grouped.entries) {
      final deviceId = entry.key;
      final entries = entry.value;
      
      // Sort by created_at to get most recent entry first
      entries.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending (most recent first)
      });
      
      // Use most recent entry's info
      final mostRecent = entries.first;
      
      uniqueGuests.add({
        'device_id': deviceId,
        'name': mostRecent['name'] ?? '',
        'email': mostRecent['email'] ?? '',
        'phone': mostRecent['phone'] ?? '',
        'comments': mostRecent['comments'] ?? '',
        'hear_about_us': mostRecent['hear_about_us'] ?? '',
        'created_at': mostRecent['created_at'], // Most recent attendance
        'attendance_count': entries.length, // Total number of attendances
        'all_entry_ids': entries.map((e) => e['id'] as String).toList(), // For deletion
        'all_attendances': entries, // Store all attendance entries for display
        'device_doc_id': mostRecent['device_doc_id'] ?? deviceId, // For deletion
      });
    }
    
    // Sort by most recent attendance (descending)
    uniqueGuests.sort((a, b) {
      final aTime = a['created_at'] as Timestamp?;
      final bTime = b['created_at'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime); // Descending
    });
    
    return uniqueGuests;
  }
  
  void _toggleAttendanceExpansion(String expansionKey) {
    setState(() {
      if (_expandedDeviceIds.contains(expansionKey)) {
        _expandedDeviceIds.remove(expansionKey);
      } else {
        _expandedDeviceIds.add(expansionKey);
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupGuestsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    // Group all entries by their entry_date (not just unique guests)
    // This way, if a guest attended on multiple dates, they appear in each date section
    for (final entry in _allGuestEntries) {
      String dateKey;
      
      // Try to use entry_date first (more reliable)
      final entryDate = entry['entry_date'] as String?;
      if (entryDate != null && entryDate.isNotEmpty) {
        dateKey = entryDate;
      } else {
        // Fallback to created_at
        final createdAt = entry['created_at'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          dateKey = 'Unknown';
        }
      }
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      
      // For each entry, get the unique guest info to show attendance count
      final deviceId = entry['device_id'] as String? ?? '';
      final uniqueGuest = _uniqueGuests.firstWhere(
        (g) => g['device_id'] == deviceId,
        orElse: () => {
          'device_id': deviceId,
          'name': entry['name'] ?? '',
          'email': entry['email'] ?? '',
          'phone': entry['phone'] ?? '',
          'comments': entry['comments'] ?? '',
          'hear_about_us': entry['hear_about_us'] ?? '',
          'created_at': entry['created_at'],
          'attendance_count': 1,
          'all_entry_ids': [entry['id']],
          'all_attendances': [entry],
        },
      );
      
      // Create a card entry with this specific attendance's info
      grouped[dateKey]!.add({
        ...uniqueGuest,
        'current_entry': entry, // The specific entry for this date
        'current_entry_id': entry['id'],
        'current_created_at': entry['created_at'],
      });
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
    if (_selectedEntryIds.isEmpty) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    
    // Get selected entries with their device_doc_id and attendance_doc_id
    final entriesToDelete = _allGuestEntries.where((entry) {
      return _selectedEntryIds.contains(entry['id']);
    }).toList();
    
    final count = entriesToDelete.length;
    
    setState(() {
      _isDeleting = true;
    });
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final deviceCounts = <String, int>{};
      final userId = authProvider.currentUser!.uid;
      
      for (final entry in entriesToDelete) {
        final deviceId = entry['device_doc_id'] as String?;
        final attDocId = entry['attendance_doc_id'] as String?;
        if (deviceId == null || attDocId == null) continue;
        
        batch.delete(FirebaseFirestore.instance
            .collection('club').doc(userId)
            .collection('guests').doc(deviceId)
            .collection('attendances').doc(attDocId));
        
        deviceCounts[deviceId] = (deviceCounts[deviceId] ?? 0) + 1;
      }
      
      for (final e in deviceCounts.entries) {
        batch.update(FirebaseFirestore.instance
            .collection('club').doc(userId)
            .collection('guests').doc(e.key), {
          'attendance_count': FieldValue.increment(-e.value),
        });
      }
      
      await batch.commit();
      
      setState(() {
        _selectedEntryIds.clear();
        _isDeleting = false;
      });
      
      // Reload guests after deletion
      await _loadGuests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count ${count == 1 ? 'entry' : 'entries'} deleted'),
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

  void _toggleGuestSelection(String entryId) {
    setState(() {
      if (_selectedEntryIds.contains(entryId)) {
        _selectedEntryIds.remove(entryId);
      } else {
        _selectedEntryIds.add(entryId);
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
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Guests'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
        actions: [
          if (_selectedEntryIds.isNotEmpty) ...[
            InkWell(
              onTap: _isDeleting ? null : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Entries'),
                    content: Text(
                      'Are you sure you want to delete ${_selectedEntryIds.length} ${_selectedEntryIds.length == 1 ? 'entry' : 'entries'}?',
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
      body: _isLoading && _uniqueGuests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading guests...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _uniqueGuests.isEmpty
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
              : _buildGuestList(),
    );
  }

  Widget _buildGuestList() {
    final groupedGuests = _groupGuestsByDate();
    
    return SingleChildScrollView(
      controller: _scrollController,
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
              // Loading indicator at bottom when loading more
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestCard(Map<String, dynamic> guest) {
    final deviceId = guest['device_id'] as String;
    final currentEntryId = guest['current_entry_id'] as String? ?? guest['id'] as String? ?? '';
    
    // Use a unique key for expansion: device_id + entry_id
    // This ensures each entry card expands independently
    final expansionKey = '$deviceId-$currentEntryId';
    // Use entry ID for selection so each entry is selected independently
    final isSelected = _selectedEntryIds.contains(currentEntryId);
    final isExpanded = _expandedDeviceIds.contains(expansionKey);
    
    // Use current entry's time if available (for entries shown on specific dates)
    final currentCreatedAt = guest['current_created_at'] as Timestamp?;
    final createdAt = currentCreatedAt ?? (guest['created_at'] as Timestamp?);
    final dateStr = createdAt != null
        ? _formatTime(createdAt.toDate())
        : '';
    final attendanceCount = guest['attendance_count'] as int? ?? 1;
    final allAttendances = guest['all_attendances'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: Column(
        children: [
          // Main guest info
          InkWell(
            onTap: () => _toggleGuestSelection(currentEntryId),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        // Name and badge row - left aligned
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SelectableText(
                              guest['name'] ?? 'No name',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Attendance badge - positioned next to name
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$attendanceCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              guest['email'] ?? 'No email',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Builder(
                              builder: (context) {
                                final email = guest['email'] as String? ?? '';
                                final currentEntryId = guest['current_entry_id'] as String? ?? guest['id'] as String? ?? '';
                                final copyKey = '$currentEntryId-email';
                                final isCopied = _copiedEmails.contains(copyKey);
                                
                                return GestureDetector(
                                  onTap: email.isNotEmpty && email != 'No email' ? () async {
                                    await Clipboard.setData(ClipboardData(text: email));
                                    setState(() {
                                      _copiedEmails.add(copyKey);
                                    });
                                    // Remove after 2 seconds
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (mounted) {
                                        setState(() {
                                          _copiedEmails.remove(copyKey);
                                        });
                                      }
                                    });
                                  } : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isCopied ? Colors.green[50] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      isCopied ? Icons.check : Icons.copy,
                                      size: 14,
                                      color: isCopied ? Colors.green[700] : Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (guest['phone'] != null && guest['phone'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SelectableText(
                            guest['phone'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (guest['hear_about_us'] != null && guest['hear_about_us'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SelectableText(
                                  'Heard about us: ${guest['hear_about_us']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
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
                                  child: SelectableText(
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
                  // Time and expand button column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      if (attendanceCount > 1) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _toggleAttendanceExpansion(expansionKey),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View attendances',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded attendance list
          if (isExpanded && attendanceCount > 1 && allAttendances.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Attendances ($attendanceCount)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...allAttendances.asMap().entries.map((entry) {
                      final index = entry.key;
                      final attendance = entry.value as Map<String, dynamic>;
                      final attendanceTime = attendance['created_at'] as Timestamp?;
                      final attendanceDate = attendance['entry_date'] as String?;
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: index < allAttendances.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (attendanceDate != null)
                                    Text(
                                      _formatAttendanceDate(attendanceDate),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  if (attendanceTime != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(attendanceTime.toDate()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (index == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Latest',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatAttendanceDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length != 3) return dateString;
      
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
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${months[month - 1]} ${day}, ${year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}


