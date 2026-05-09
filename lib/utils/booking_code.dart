import 'dart:convert';

import 'package:crypto/crypto.dart';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String bookingCodeFor(String bookingId) {
  final digest = sha256.convert(utf8.encode(bookingId)).bytes;
  final buf = StringBuffer();
  for (int i = 0; i < 6; i++) {
    buf.write(_crockford[digest[i] % 32]);
  }
  final raw = buf.toString();
  return '${raw.substring(0, 3)}-${raw.substring(3, 6)}';
}
