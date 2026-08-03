import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/auth/data/auth_repository.dart';
import 'package:renocharge/features/auth/domain/uzivatel.dart';

Uzivatel _uzivatel(String jmeno) =>
    Uzivatel(uid: 'u1', jmeno: jmeno, email: 'kdokoli@firma.cz');

void main() {
  // Účty zakládá správce v konzoli Firebase a ta neumí vyplnit jméno,
  // takže tohle je cesta, kterou projde pozdrav u většiny uživatelů.
  group('jmenoZEmailu', () {
    test('tečka odděluje jméno a příjmení', () {
      expect(
        AuthRepository.jmenoZEmailu('jana.novakova@firma.cz'),
        'Jana Novakova',
      );
    });

    test('funguje i podtržítko a pomlčka', () {
      expect(AuthRepository.jmenoZEmailu('jan_novak@firma.cz'), 'Jan Novak');
      expect(AuthRepository.jmenoZEmailu('jan-novak@firma.cz'), 'Jan Novak');
    });

    test('jednoslovný e-mail dá jedno jméno', () {
      expect(AuthRepository.jmenoZEmailu('svihalek@firma.cz'), 'Svihalek');
    });

    test('nesmyslný vstup nespadne, jen vrátí prázdno', () {
      expect(AuthRepository.jmenoZEmailu(''), '');
      expect(AuthRepository.jmenoZEmailu('@firma.cz'), '');
      expect(AuthRepository.jmenoZEmailu('bez-zavinace'), '');
    });

    test('zdvojené oddělovače nedělají prázdné části', () {
      expect(AuthRepository.jmenoZEmailu('jan..novak@firma.cz'), 'Jan Novak');
    });
  });

  group('maHotovyOnboarding', () {
    test('bez onboarding_at aplikace pustí jen na úvodní nastavení', () {
      expect(_uzivatel('Jana').maHotovyOnboarding, isFalse);
    });

    test('s vyplněným časem je nastavení hotové', () {
      const profil = Uzivatel(
        uid: 'u1',
        jmeno: 'Jana Nováková',
        email: 'jana@firma.cz',
        osobniCislo: '12345',
      );
      expect(profil.maHotovyOnboarding, isFalse);

      final dokonceny = Uzivatel(
        uid: profil.uid,
        jmeno: profil.jmeno,
        email: profil.email,
        osobniCislo: profil.osobniCislo,
        onboardingAt: DateTime(2026, 8, 3),
      );
      expect(dokonceny.maHotovyOnboarding, isTrue);
    });
  });

  group('krestniJmeno', () {
    test('vezme první slovo', () {
      expect(_uzivatel('Jana Nováková').krestniJmeno, 'Jana');
    });

    test('bez jména oslovíme neutrálně', () {
      expect(_uzivatel('').krestniJmeno, 'kolego');
      expect(_uzivatel('   ').krestniJmeno, 'kolego');
    });
  });
}
