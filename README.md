# Inventory Management

Windows, Linux ve Android üzerinde yerel çalışan, çevrimdışı öncelikli
(offline-first) envanter yönetim uygulaması. Tek kod tabanı (Flutter/Dart),
yerel SQLite, yalnızca karanlık mod.

## Hazır sürüm (kurulum)

**Linux — tek komutla kur + çalıştır:**

```sh
curl -sL https://github.com/omerseyfettinozd/inventory-management/releases/latest/download/inventory-management-linux-x64.tar.gz | tar -xz -C /tmp && /tmp/inventory-management/install.sh && rm -rf /tmp/inventory-management
```

Bu komut uygulamayı `~/.local/share/inventory-management` altına kurar,
başlatıcı kaydını ve ikonu işler — sonrasında **Alt+Space (veya menüde ara) →
"Inventory Management"** ile açılır. Sudo istemez. Veriler
`~/.local/share/inventory_management/` altında oluşur.

**Android:** [Releases](https://github.com/omerseyfettinozd/inventory-management/releases)
sayfasından `inventory-management-android.apk` dosyasını telefona indirip açın
(bilinmeyen kaynaklara bir kez izin gerekir).

**Windows:** bu makineden derlenemez; Windows bilgisayarda depo kökünden:

```powershell
flutter build windows --release
powershell -ExecutionPolicy Bypass -File packaging\windows\Install.ps1
```

Kurulum `%LocalAppData%\InventoryManagement` altına yapılır ve Başlat
menüsüne "Inventory Management" kısayolu eklenir (Win tuşu + yazarak bulunur).

## Özellikler

- Hiyerarşik kategori ağacı (sınırsız derinlik, klasör mantığı, `parent_id`).
- Ürün ekleme: görsel (galeri/kamera/kamera yerine masaüstünde dosya seçici),
  isim, çok satırlı açıklama, adet (negatif engelleme), kategori konumu.
- Ürün formundan ayrılmadan "Kategori Ekle" modalı (isim + üst kategori seçimi).
- Envanter ekranı: gerçek zamanlı arama (ad + açıklama, Türkçe duyarsız:
  "yildiz" → "Yıldız" bulunur), sıralama (Ad / Stok / Tarih, artan-azalan).
- Favoriler: karttaki yıldıza dokunarak işaretleme; en üstte bağımsız
  sıralamalı "Favoriler" bölümü, altında bağımsız sıralamalı "Tüm ürünler".
- Kategoriler ekranı: genişletince içindeki ürünler resimli listelenir
  (ad + adet; boşsa "Bu kategoride ürün yok.").
- Satır/kart üzerinden düzenleme (tüm alanlar).
- Onaylı silme: "Bu ürünü envanterden silmek istediğinize emin misiniz?"
  onayı olmadan silme yapılmaz; onayda kayıt + ilişkili görsel dosyası silinir.
- Görseller veritabanına yazılmaz; uygulama veri klasörü altında saklanır,
  veritabanında yalnızca göreli yol (`images/<uuid>.<uzantı>`) tutulur.

## Kurulum

Gerekenler: Flutter SDK 3.22+ (Dart 3.4+). Depoda platform iskeleleri
(`android/`, `windows/`, `linux/`) hazır gelir; yalnızca `android/app/build.gradle`
ve `android/app/src/main/AndroidManifest.xml` projeye özeldir.

```sh
flutter doctor
flutter pub get
```

## Çalıştırma

```sh
flutter run -d windows
flutter run -d linux
flutter run -d android
flutter test
flutter analyze
```

## Derleme (paketleme)

```sh
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build linux --release
```

Windows/Linux çıktılarında SQLite FFI ikilisinin pakete gömüldüğünü doğrulayın
(uygulama çevrimdışıyken temiz makinede açılmalıdır).

## Veri konumu

- Veritabanı: `<uygulama-destek-dizini>/inventory.db`
  (`getApplicationSupportDirectory()`, tüm platformlarda aynı).
- Görseller: `<uygulama-destek-dizini>/images/<uuid>.<uzantı>`
  (izin verilenler: `jpg`, `jpeg`, `png`, `webp`; üst sınır 10 MB).
- Yedekleme bu iki varlığı kapsar.

## Klasör ağacı

```text
pubspec.yaml
analysis_options.yaml
lib/
  main.dart
  theme/app_theme.dart
  models/category.dart        (re-export: db/app_database.dart)
  models/product.dart         (re-export: db/app_database.dart)
  db/app_database.dart        (SQLite + modeller + recursive CTE + sayfalama)
  services/image_store.dart   (dosya deposu + orphan taraması)
  utils/validators.dart       (saf doğrulayıcılar)
  providers/inventory_provider.dart
  screens/home_screen.dart
  screens/inventory_tab.dart
  screens/categories_tab.dart
  screens/product_form_screen.dart
  widgets/product_card.dart
  widgets/category_filter_tree.dart
  widgets/dialogs.dart
  widgets/app_icons.dart
test/validators_test.dart
android/                      (bildirim + derleme yapılandırması)
docs/
  01-mimari-belge.md
  02-faz-plani.md
```

Not: `screens/` içindeki `InventoryTab` ve ürün formu, odaklı yerel
widgetlar içerir; `widgets/` dizini yeniden kullanılabilir sürümlerin
bileşen kitaplığıdır.

## Arayüz kuralları

- Yalnızca karanlık mod (`ThemeMode.dark` sabit). Açık mod yoktur.
- Palet: zemin `#0A0A0A`, kart `#141414` / `#1E1E1E`, metin `#F5F5F0` /
  `#EAE6DF`, çizgi `#262626`, ikincil `#8E8E93`.
- Arayüzde emoji yasaktır; yalnızca ince hatlı (outlined) vektör ikonlar.
- Rakamlar tek aralıklıdır (`FontFeature.tabularFigures`).
