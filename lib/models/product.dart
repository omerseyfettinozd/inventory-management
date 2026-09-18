// Ürün modeli: tek doğruluk kaynağı `lib/db/app_database.dart` içindedir.
//
// Bu dosya, mimari belgedeki dosya haritasıyla (`lib/models/...`) uyum için
// yeniden dışa vurum (re-export) sağlar; ayrı bir sınıf tanımı içermez,
// böylece çift tanım/çakışma oluşmaz.
export 'package:inventory_management/db/app_database.dart'
    show Product, ProductSortField;
