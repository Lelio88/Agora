import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a level is read from its code, and unknown means the quietest', () {
    expect(ProfileLinkLevel.fromCode('details'), ProfileLinkLevel.details);
    expect(ProfileLinkLevel.fromCode('busy'), ProfileLinkLevel.busy);
    expect(ProfileLinkLevel.fromCode('invisible'), ProfileLinkLevel.busy);
    expect(ProfileLinkLevel.fromCode(null), ProfileLinkLevel.busy);
  });

  test('only a plausible code passes before reaching the server', () {
    expect(looksLikeProfileLinkCode('ABCD2345'), isTrue);
    expect(looksLikeProfileLinkCode(' abcd2345 '), isTrue);
    expect(looksLikeProfileLinkCode('ABCD234'), isFalse);
    expect(looksLikeProfileLinkCode('ABCD23450'), isFalse);
    // Ni 0, ni 1, ni O, ni I : l'alphabet évite les confusions.
    expect(looksLikeProfileLinkCode('ABCD2O45'), isFalse);
    expect(looksLikeProfileLinkCode('ABCD2145'), isFalse);
  });
}
