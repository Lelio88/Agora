import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidEmail', () {
    for (final (input, expected) in [
      ('zoe@example.com', true),
      ('  zoe@example.com  ', true),
      ('zoe@example', false),
      ('zoe.example.com', false),
      ('zo e@example.com', false),
      ('', false),
    ]) {
      test('"$input" → $expected', () => expect(isValidEmail(input), expected));
    }
  });

  group('checkPassword', () {
    test('accepts 8 characters mixing letters and digits', () {
      expect(checkPassword('abcdefg1'), isNull);
    });
    test('rejects fewer than 8 characters', () {
      expect(checkPassword('abc1'), PasswordIssue.tooShort);
    });
    test('rejects letters only', () {
      expect(checkPassword('abcdefgh'), PasswordIssue.needsLettersAndDigits);
    });
    test('rejects digits only', () {
      expect(checkPassword('12345678'), PasswordIssue.needsLettersAndDigits);
    });
  });

  group('isValidCode', () {
    test('accepts exactly 6 digits', () => expect(isValidCode('192527'), true));
    test('ignores surrounding spaces', () {
      expect(isValidCode(' 192527 '), true);
    });
    test('rejects 5 digits', () => expect(isValidCode('19252'), false));
    test('rejects letters', () => expect(isValidCode('19252a'), false));
  });

  group('isValidDisplayName', () {
    test('accepts a short name', () => expect(isValidDisplayName('Zoé'), true));
    test('rejects blanks', () => expect(isValidDisplayName('   '), false));
    test('rejects more than 60 characters', () {
      expect(isValidDisplayName('a' * 61), false);
    });
  });
}
