import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationCodeService {
  InvitationCodeService(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _length = 8;

  final Random _random = Random.secure();

  String _generateCode() {
    return List.generate(
      _length,
      (_) => _characters[_random.nextInt(_characters.length)],
    ).join();
  }

  Future<String> generateUniqueCode() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _generateCode();

      final document = await _firestore
          .collection('invitations')
          .doc(code)
          .get();

      if (!document.exists) {
        return code;
      }
    }

    throw StateError('Could not generate a unique invitation code.');
  }

  static String normalize(String value) {
    return value.trim().replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  }
}
