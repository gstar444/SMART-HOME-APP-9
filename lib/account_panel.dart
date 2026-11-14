import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final RegExp _usernameShape = RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)*$');

/// यूज़रनेम की जाँच। null मतलब सही।
String? usernameProblem(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.length < 3 || v.length > 20) return '3 से 20 अक्षर लिखें';
  if (!_usernameShape.hasMatch(v)) {
    return 'सिर्फ़ a-z, 0-9, _ और डॉट; शुरू या आख़िर में डॉट नहीं';
  }
  return null;
}

/// अकाउंट पैनल में नाम और यूज़रनेम।
class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snap) {
        final username = snap.data?.data()?['username'] as String?;
        final name = (user.displayName ?? '').trim();
        return ListTile(
          leading: CircleAvatar(
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
          title: Text(name.isEmpty ? 'उपयोगकर्ता' : name),
          subtitle: Text('@${username ?? '—'}\n${user.email ?? ''}'),
          isThreeLine: true,
        );
      },
    );
  }
}

/// नया यूज़रनेम बनाता है और पुराना बंद करता है (एक ही transaction में)।
Future<String?> applyUsername(
  User user,
  String? oldName,
  String newName,
) async {
  final problem = usernameProblem(newName);
  if (problem != null) return problem;
  if (oldName == newName) return null;
  final db = FirebaseFirestore.instance;
  final newRef = db.collection('usernames').doc(newName);
  final userRef = db.collection('users').doc(user.uid);
  final oldRef = (oldName == null || oldName.isEmpty)
      ? null
      : db.collection('usernames').doc(oldName);
  try {
    await db.runTransaction((tx) async {
      final newSnap = await tx.get(newRef);
      final oldSnap = oldRef == null ? null : await tx.get(oldRef);
      if (newSnap.exists) throw StateError('taken');
      tx.set(newRef, {'uid': user.uid, 'email': user.email});
      if (oldSnap != null &&
          oldSnap.exists &&
          oldSnap.data()?['uid'] == user.uid) {
        tx.delete(oldSnap.reference);
      }
      tx.set(userRef, {'username': newName}, SetOptions(merge: true));
    });
    return null;
  } on StateError {
    return 'यह यूज़रनेम पहले से किसी और का है';
  } catch (_) {
    return 'बदल नहीं पाया, फिर कोशिश करें';
  }
}

/// "यूज़रनेम बदलें" संवाद, फिर नया नाम सेव।
Future<void> startUsernameChange(BuildContext context, User user) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final oldName = snap.data()?['username'] as String?;
  if (!context.mounted) return;
  final ctrl = TextEditingController(text: oldName ?? '');
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('यूज़रनेम बदलें'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(
          labelText: 'नया यूज़रनेम',
          hintText: 'ashish.home',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('रद्द करें'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toLowerCase()),
          child: const Text('सेव करें'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (picked == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final err = await applyUsername(user, oldName, picked);
  messenger.showSnackBar(
    SnackBar(content: Text(err ?? 'यूज़रनेम बदल गया: @$picked')),
  );
}
