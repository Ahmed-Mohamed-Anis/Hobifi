import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_haven/utils/booking_code.dart';

void main() {
  group('bookingCodeFor', () {
    test('returns 7 chars in XXX-XXX format', () {
      final code = bookingCodeFor('b5b8f7e0-1234-4abc-9def-000000000001');
      expect(code.length, 7);
      expect(code[3], '-');
    });

    test('is deterministic for the same id', () {
      const id = 'b5b8f7e0-1234-4abc-9def-000000000001';
      expect(bookingCodeFor(id), bookingCodeFor(id));
    });

    test('differs for different ids', () {
      final a = bookingCodeFor('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      final b = bookingCodeFor('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(a, isNot(b));
    });

    test('uses only Crockford base32 chars (no I/L/O/U)', () {
      final code = bookingCodeFor('some-random-booking-id-12345');
      final body = code.replaceAll('-', '');
      for (final ch in body.split('')) {
        expect('0123456789ABCDEFGHJKMNPQRSTVWXYZ'.contains(ch), isTrue,
            reason: 'unexpected char: $ch in $code');
      }
    });
  });
}
