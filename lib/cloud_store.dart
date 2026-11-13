import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'secure_storage.dart';

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

  /// Firestore से MQTT और ESP32 IP की सेटिंग लेता है। न मिले तो null।
  static Future<CloudSetup?> loadSetup() async {
    final data = await loadConfig();
    if (data == null || data['host'] == null) return null;
    return CloudSetup.fromMap(data);
  }

  /// सेटअप को Firestore और फ़ोन की secure storage, दोनों में सेव करता है।
  static Future<void> saveSetup({
    required String host,
    required int port,
    required String homeId,
    required String username,
    required String password,
    required String espUrl,
    required SecureStore store,
  }) async {
    final cfg = CloudConfig(
      host: host,
      port: port,
      homeId: homeId,
      username: username,
      password: password,
    );
    await saveConfig({
      'host': host,
      'port': port,
      'homeId': homeId,
      'username': username,
      'password': password,
      'espUrl': espUrl,
    });
    await store.saveCloud(cfg);
  }
}

class CloudSetup {
  const CloudSetup({
    required this.host,
    required this.port,
    required this.espUrl,
  });

  final String host;
  final int port;
  final String espUrl;

  factory CloudSetup.fromMap(Map<String, dynamic> m) => CloudSetup(
    host: (m['host'] as String?) ?? '',
    port: (m['port'] as num?)?.toInt() ?? 8883,
    espUrl: (m['espUrl'] as String?) ?? '',
  );
}
