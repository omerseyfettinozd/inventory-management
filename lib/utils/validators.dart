/// Form dogrulayicilari (saf fonksiyonlar, unit-test dostu).
///
/// Bu dosya Flutter bagimliligi icermez; tum fonksiyonlar saf Dart'tir.
/// Tum hata mesajlari Turkce ve emojisizdir.
///
/// Kullanim:
/// ```dart
/// final hata = Validators.validateProductName(nameController.text);
/// if (hata != null) { /* goster */ }
/// ```
class Validators {
  Validators._();

  /// Urun adi kurallari: zorunlu, en az 2, en fazla 120 karakter.
  ///
  /// Gecerliyse `null`, degilse Turkce hata mesaji doner.
  static String? validateProductName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Ürün adı zorunludur.';
    }
    if (text.length < 2) {
      return 'Ürün adı en az 2 karakter olmalıdır.';
    }
    if (text.length > 120) {
      return 'Ürün adı en fazla 120 karakter olabilir.';
    }
    return null;
  }

  /// Kategori adi kurallari ("Kategori Ekle" modali icin).
  ///
  /// Zorunlu, en az 2, en fazla 60 karakter.
  static String? validateCategoryName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Kategori adı zorunludur.';
    }
    if (text.length < 2) {
      return 'Kategori adı en az 2 karakter olmalıdır.';
    }
    if (text.length > 60) {
      return 'Kategori adı en fazla 60 karakter olabilir.';
    }
    return null;
  }

  /// Adet kurallari: zorunlu, tam sayi, negatif olamaz.
  ///
  /// Sifir kabul edilir (stokta yok anlami). Ondalik, harf ya da
  /// bosluk iceren girdi gecersizdir. Gecerliyse `null` doner.
  static String? validateQuantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Adet zorunludur.';
    }
    if (!_integerPattern.hasMatch(text)) {
      return 'Adet geçerli bir tam sayı olmalıdır.';
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      return 'Adet geçerli bir tam sayı olmalıdır.';
    }
    if (parsed < 0) {
      return 'Adet negatif olamaz.';
    }
    if (parsed > 9999999) {
      return 'Adet en fazla 9999999 olabilir.';
    }
    return null;
  }

  /// Kategori secimi kurallari: null ya da gecersiz id kabul edilmez.
  static String? validateCategoryId(int? value) {
    if (value == null) {
      return 'Kategori seçimi zorunludur.';
    }
    if (value <= 0) {
      return 'Geçerli bir kategori seçiniz.';
    }
    return null;
  }

  /// Metni tam sayiya cevirir; cevrilemezse `null` doner.
  ///
  /// Kirpma (trim) yapar. Negatiflik kontrolu yapmaz; negatiflik
  /// karari [validateQuantity] fonksiyonuna aittir. Form disi
  /// toplu islemler ve siralama anahtarlari icin kullanilabilir.
  static int? parseQuantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (!_integerPattern.hasMatch(text)) {
      return null;
    }
    return int.tryParse(text);
  }

  /// Istege bagli aciklama alani icin ust sinir kontrolu.
  ///
  /// Bos aciklama gecerlidir; 2000 karakterden uzunu gecersizdir.
  static String? validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 2000) {
      return 'Açıklama en fazla 2000 karakter olabilir.';
    }
    return null;
  }

  /// Basinda opsiyonel isaret, ardindan yalnizca rakam.
  /// Ornekler: "0", "12", "-3", "+7". "3.5", "1 000", "" eslesmez.
  static final RegExp _integerPattern = RegExp(r'^[+-]?\d+$');
}
