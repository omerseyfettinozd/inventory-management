import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/utils/validators.dart';

void main() {
  group('validateProductName', () {
    test('boş ad reddedilir', () {
      expect(Validators.validateProductName(null), isNotNull);
      expect(Validators.validateProductName(''), isNotNull);
      expect(Validators.validateProductName('   '), isNotNull);
    });

    test('çok kısa ad reddedilir', () {
      expect(Validators.validateProductName('A'), isNotNull);
    });

    test('geçerli ad kabul edilir', () {
      expect(Validators.validateProductName('Kablo'), isNull);
      expect(
        Validators.validateProductName('  USB-C Kablo 2m  '),
        isNull,
      );
    });
  });

  group('validateQuantity', () {
    test('boş değer reddedilir', () {
      expect(Validators.validateQuantity(null), isNotNull);
      expect(Validators.validateQuantity(''), isNotNull);
    });

    test('negatif değer reddedilir', () {
      expect(Validators.validateQuantity('-1'), isNotNull);
      expect(Validators.validateQuantity('-30'), isNotNull);
    });

    test('harf ve ondalık reddedilir', () {
      expect(Validators.validateQuantity('abc'), isNotNull);
      expect(Validators.validateQuantity('3.5'), isNotNull);
      expect(Validators.validateQuantity('1 000'), isNotNull);
    });

    test('sıfır ve pozitif tam sayı kabul edilir', () {
      expect(Validators.validateQuantity('0'), isNull);
      expect(Validators.validateQuantity('126'), isNull);
      expect(Validators.validateQuantity('  42  '), isNull);
    });
  });

  group('validateCategoryId', () {
    test('seçimsiz kategori reddedilir', () {
      expect(Validators.validateCategoryId(null), isNotNull);
      expect(Validators.validateCategoryId(0), isNotNull);
      expect(Validators.validateCategoryId(-2), isNotNull);
    });

    test('geçerli kategori kabul edilir', () {
      expect(Validators.validateCategoryId(1), isNull);
      expect(Validators.validateCategoryId(57), isNull);
    });
  });

  group('parseQuantity', () {
    test('çevrilemeyen girdi null döner', () {
      expect(Validators.parseQuantity(null), isNull);
      expect(Validators.parseQuantity(''), isNull);
      expect(Validators.parseQuantity('3.5'), isNull);
    });

    test('geçerli girdi çevrilir', () {
      expect(Validators.parseQuantity('126'), 126);
      expect(Validators.parseQuantity('0'), 0);
    });
  });
}
