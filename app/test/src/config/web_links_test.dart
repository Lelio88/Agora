import 'package:agora/src/config/web_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the web address comes from the build, or stays unknown', () {
    expect(parseWebBaseUrl(''), isNull);
    expect(parseWebBaseUrl('agora.example'), isNull);
    expect(parseWebBaseUrl('ftp://agora.example'), isNull);
    expect(parseWebBaseUrl('https://agora.example'), isNotNull);
  });

  test('an invitation link opens the join page of the web version', () {
    expect(
      inviteLink(Uri.parse('https://agora.example'), 'abcd2345').toString(),
      'https://agora.example/#/join/ABCD2345',
    );
    expect(
      inviteLink(
        Uri.parse('https://example.org/agora/'),
        'ABCD2345',
      ).toString(),
      'https://example.org/agora/#/join/ABCD2345',
    );
  });
}
