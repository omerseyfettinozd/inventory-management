# Inventory Management — Faz Bazlı Geliştirme Yol Haritası

**Sürüm:** v1.0 (2026-09-17)
**İlke:** Yol haritasındaki dosya adları ve kararlar mimari belgeyle birebir eşleşir. Aşağıdaki fazlar sırayla uygulanmıştır.
**Kilitli kararlar:** State `provider`; DB kökü `getApplicationSupportDirectory()`; görsel öneki `images/`; kategori silme = ürünlü dalı engelle+yönlendir; adet 0 geçerli; açıklama ve görsel opsiyonel.

---

## Phase 0 — Hazırlık + Tema Jetonları

**Hedef:** Flutter SDK, proje iskeleti, bağımlılık kilidi ve dark-only tema jetonlarının en başta kurulması (ekranlardan önce; geç tema yeniden işçiliği önler).
**Çıktı:** `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart` (iskele), `lib/theme/app_theme.dart` (jetonlar + `darkTheme`), platform klasörleri (`android/`, `windows/`, `linux/`).
**Kabul:** `flutter doctor` hatasız; `flutter pub get` temiz; `flutter run -d windows/linux` ve `flutter build apk --debug` başarılı; `pubspec.lock` içinde `sqflite`, `sqflite_common_ffi`, `path`, `path_provider`, `image_picker`, `file_picker`, `provider`, `intl`, `uuid` sabit; `ThemeMode.dark` sabit, açık mod kodu yok; palet ve `tabularFigures` jetonu tanımlı.
**Bağımlılık:** Yok (giriş).

## Phase 1 — Veri Katmanı

**Hedef:** SQLite şeması, modeller, DB yardımcısı, migration iskeleti.
**Çıktı:** `lib/models/category.dart`, `lib/models/product.dart`, `lib/db/app_database.dart` (DDL + `UNIQUE(parent,name)` + göreli-yol `CHECK` + indexler + `PRAGMA foreign_keys=ON` + `user_version` + transaction CRUD + recursive CTE + `LIMIT/OFFSET` + `COUNT`), `test/db_crud_test.dart` (taslak içeriği bu pakette `validators_test` ile başlar, DB testleri genişletilir).
**Kabul:** Tablolar oluşur; FK açık; negatif stok reddedilir; aynı düzeyde yinelenen kategori adı reddedilir; kendini ebeveyn reddedilir; derin döngü uygulama katmanında reddedilir (test yeşil); alt-ağaç sorgusu doğru kümeyi döndürür.
**Bağımlılık:** Phase 0.

## Phase 2 — Dosya Deposu

**Hedef:** Görsellerin `<support>/images/` altında saklanması, DB'de yalnızca `images/<uuid>.<ext>` tutulması.
**Çıktı:** `lib/services/image_store.dart` (init + `saveImage` + `resolve` + `deleteByRelative` + `replace` + `scanOrphans` + `tmp` temizliği), `test/image_store_test.dart` (genişletme).
**Kabul:** Kopyalama doğru öneke yapılır; uzantı (`jpg/jpeg/png/webp`) + 10 MB + sihirli bayt denetimi çalışır; commit-başarısızlıkta kopya geri alınır; `replace` eskiyi commit sonrası siler; orphan taraması karşılıksız dosyaları raporlar/temizler; kayıp dosyada okuma çökmez.
**Bağımlılık:** Phase 1.

## Phase 3 — Kategori Hiyerarşisi (n-seviye)

**Hedef:** Sınırsız derinlikte klasör ağacı; iki kademeli dropdown değildir.
**Çıktı:** `lib/providers/inventory_provider.dart` (kategori bölümü: `addCategory`, `renameCategory`, `deleteCategory`, ağaç kurma, ata kontrolü), `lib/screens/categories_tab.dart`, `lib/widgets/category_filter_tree.dart` (breadcrumb + genişletilebilir ağaç).
**Kabul:** Ekle/yeniden adlandır/sil çalışır; döngüsel ebeveyn ataması engellenir; ürünlü dal silinmek istenirse engelleme diyaloğu ürün sayısını gösterir ve taşı/sil yönergesi verir; recursive alt-ağaç sorgusu doğru ürün kümesini döndürür.
**Bağımlılık:** Phase 1-2.

## Phase 4 — Ürün Formu (ekle + düzenle tek form)

**Hedef:** Doğrulamalı form ve formdan ayrılmadan kategori ekleme.
**Çıktı:** `lib/screens/product_form_screen.dart`, `lib/widgets/dialogs.dart` (`AddCategoryDialog` ebeveyn seçimli), `lib/utils/validators.dart`, `test/validators_test.dart`.
**Kabul:** Zorunlular (isim, adet, kategori) boş geçilemez; adet yalnızca pozitif tam sayı (0 geçerli); `Kategori Ekle` modalı isim + üst-kategori seçimi içerir, varsayılan mevcut seçimdir, kaydetme sonrası yeni kategori seçili hale gelir ve forma kaldığı yerden devam edilir; görsel yolu `ImageStore` üzerinden alınır; Android galeri+kamera, masaüstü dosya seçici çalışır.
**Bağımlılık:** Phase 2-3.

## Phase 5 — Envanter Ekranı

**Hedef:** Ana liste: gerçek zamanlı arama, ağaç filtresi, sıralama, sayfalama.
**Çıktı:** `lib/screens/home_screen.dart`, `lib/screens/inventory_tab.dart`, `lib/widgets/product_card.dart`, provider filtre/sıralama bölümü.
**Kabul:** Kategori filtresi alt kategorileri içerir; isim+a açıklama araması gerçek zamanlı (~300 ms debounce), `COLLATE NOCASE` + kaçışlı; sıralamalar (Ad/Stok/Tarih, Artan/Azalan) doğru; varsayılan Tarih yeniden-eskite; liste sayfalı (100), boş-sonuç ve yükleme durumları gösterilir; tüm rakamlar tabular.
**Bağımlılık:** Phase 3-4.

## Phase 6 — Düzenle / Onaylı Sil

**Hedef:** Satır/kart üzerinden tüm alanların güncellenmesi ve çift adımlı silme.
**Çıktı:** `product_form_screen.dart` düzenleme modu, `ConfirmDeleteDialog` (`dialogs.dart` içinde), provider `updateProduct`/`deleteProduct`.
**Kabul:** Görsel/isim/açıklama/adet/kategori konumu güncellenir; görsel değişiminde eski dosya commit sonrası temizlenir; silmede `Bu ürünü envanterden silmek istediğinize emin misiniz?` onayı olmadan silme olmaz (metin aynen); onayda kayıt + dosya birlikte silinir.
**Bağımlılık:** Phase 4-5.

## Phase 7 — Tema Polish ve Denetim

**Hedef:** Dark-only, emojisiz, endüstriyel görünümün kapatılması.
**Çıktı:** `app_theme.dart` son geçiş, `app_icons.dart` (outlined set), metin/diakritik düzeltmeleri.
**Kabul:** Zemin `#0A0A0A/#141414/#1E1E1E`, metin `#F5F5F0/#EAE6DF`, çizgi `#262626`, ikincil `#8E8E93` dışına zemin/metin rengi çıkmaz (yalnızca durum bildirimlerinde doygunluğu düşürülmüş `success/warning/danger` tonlarına izin verilir); arayüzde sıfır emoji (tarama temiz); yalnızca ince çizgili ikonlar; adet/tarih tabular; Türkçe diakritikler doğru.
**Bağımlılık:** Phase 5-6.

## Phase 8 — Platform Paketleme ve Kabul

**Hedef:** Üç platformda kurulabilir çıktı ve uçtan uca doğrulama.
**Çıktı:** `android/app/build.gradle` (applicationId, sürüm), `windows/packaging`, `linux/packaging` notları, `README.md`, `CHANGELOG.md`.
**Kabul komutları:** `flutter build apk --release`, `flutter build appbundle --release`, `flutter build windows --release`, `flutter build linux --release`; FFI SQLite ikilisinin Windows/Linux paketine gömüldüğü doğrulanır; imzalama tamamlanır; uçak-modu kabul senaryosu üç platformda geçer: kategori ağacı kur -> ürün ekle -> ara/filtrele/sırala -> düzenle -> onaylı sil -> yeniden başlatıp veri bütünlüğünü gör.
**Bağımlılık:** Phase 0-7.

---

## İzlenebilirlik (şartname -> dosya)

| Şartname | Dosya |
|---|---|
| Hiyerarşik kategori + form-içi Kategori Ekle | `app_database.dart`, `inventory_provider.dart`, `categories_tab.dart`, `category_filter_tree.dart`, `dialogs.dart`, `product_form_screen.dart` |
| Ürün ekleme + validasyon + negatif engelleme | `validators.dart`, `product_form_screen.dart`, `app_database.dart` |
| Envanter: liste/arama/filtre/sıralama | `inventory_tab.dart`, `product_card.dart`, `inventory_provider.dart` |
| Düzenleme (tüm alanlar) | `product_form_screen.dart`, `image_store.dart` |
| Onaylı silme (metin aynen + dosya temizliği) | `dialogs.dart`, `inventory_tab.dart`, `inventory_provider.dart`, `image_store.dart` |
| Dark-only + palet + emojisiz + tabular | `app_theme.dart`, `app_icons.dart`, tüm ekran/widget dosyaları |
| Offline SQLite + göreli yol | `app_database.dart`, `image_store.dart`, `main.dart` (başlatma sırası) |
