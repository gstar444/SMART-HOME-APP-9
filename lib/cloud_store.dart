import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// लॉगिन यूज़र की सेटिंग (MQTT, IP) Firestore में users/{uid} पर रहती है।
class CloudStore {
  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<Map<String, dynamic>?> loadConfig() async {
    final doc = _doc();
    if (doc == null) return null;
    final snap = await doc.get();
    return snap.data();
  }

  static Future<void> saveConfig(Map<String, dynamic> data) async {
    final doc = _doc();
    if (doc == null) throw StateError('लॉगिन नहीं है');
    await doc.set(data, SetOptions(merge: true));
  }
}
