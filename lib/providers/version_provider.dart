import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../main.dart';

class VersionProvider extends ChangeNotifier {
  String? _latestVersion;
  StreamSubscription<DocumentSnapshot>? _sub;

  bool get needsUpdate => _latestVersion != null && _latestVersion != appVersion;

  VersionProvider() {
    _sub = FirebaseFirestore.instance
        .collection('app')
        .doc('version')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _latestVersion = snapshot.data()?['latest'] as String?;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

