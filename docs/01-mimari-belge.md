# Inventory Management — Teknik Mimari Belgesi

**Sürüm:** v1.0 (2026-09-17)
**Kapsam:** Windows + Linux + Android, tek kod tabanı, çevrimdışı öncelikli (offline-first), yerel SQLite.
**Kaynak kök:** `/home/chaple/Belgeler/Inventory Managment/`
**Kısıtlar:** Sadece karanlık mod. Emoji yasaktır. Renk paleti dışına çıkılmaz. Rakamlar tabular hizalanır.

---

## 1. Kararlar Özeti (kilitli)

| Konu | Karar | Gerekçe |
|---|---|---|
| Dil / UI | Flutter 3.22+ / Dart 3.4+ | Üç platforma tek kod tabanı, AOT performansı, merkezi tema ile dark-only kolaylığı |
| State | `provider` 6.1+ (tek seçim; riverpod yok) | Küçük-orta offline uygulama için yeterli sadelik ve test edilebilirlik |
| Android SQLite | `sqflite` | Gömülü SQLite, ek kurulum yok |
| Windows/Linux SQLite | `sqflite_common_ffi` | FFI ile paketlenmiş SQLite; sistem SQLite sürüm farklarından bağımsızlık |
| Yol çözümleme | `path` + `path_provider` | Göreli yol üretiminde tutarlılık, platform güvenli dizinleri |
| Görsel seçimi | Android: `image_picker` (galeri+kamera); Masaüstü: `file_picker` (dosya seçici, kamera yok) | `image_picker` masaüstünde sınırlı; masaüstünde kamera akışı desteklenmez, dosya seçici tek yoldur |
| ID üretimi (dosya adı) | `uuid` v4 | Çakışmasız dosya adı, kullanıcı girdisinden bağımsız |
| Tarih/sayı biçimi | `intl` | Yerelleştirilmiş tarih ve sayı gösterimi |
| Lint/test | `flutter_lints`, `flutter_test` | Standart kalite kapısı |
| DB kökü (tek karar) | Tüm platformlarda `getApplicationSupportDirectory()` | Taşınma/kullanıcı-adı değişimine dayanıklı, yedeklenebilir, gizli uygulama verisi |
| Görsel dizini (tek karar) | `<support>/images/` ; DB değeri `images/<uuid>.<ext>` | `product_images/` varyantı elenmiştir; önek her yerde `images/` |
| Kategori silme politikası (tek karar) | `categories` CASCADE + `products` RESTRICT; içinde ürün olan dal silinemez, önce ürün taşınır/silinir | Şema + UX eşleşir; `altıyla sil / taşı / engelle` listesinden `engelle + yönlendir` seçilmiştir |
| Adet 0 | Geçerli (anlamı: `Stokta yok`) | Şema `CHECK(quantity >= 0)` ile tutarlı |
| Açıklama | Opsiyonel (`DEFAULT ''`) | Zorunlular: isim, adet, kategori. Görsel opsiyonel |

---

## 2. Katmanlı Mimari

```text
UI (screens + widgets, dark-only tema)
  -> State (InventoryProvider, ChangeNotifier)
    -> Service (ImageStore, Validators)
      -> Data (AppDatabase: SQLite + transaction + recursive CTE)
        -> OS (Support dizini: inventory.db + images/)
```

- **UI** yalnızca tema, liste, form, filtre ve onay diyaloglarından sorumludur. Açık tema kodu bulundurulmaz (`ThemeMode.dark` sabit).
- **State** envanter listesi, arama metni, kategori filtresi ve sıralama durumunu tutar.
- **Service** UI ile SQLite/dosya sistemi arasındaki tek geçiş noktasıdır. Negatif stok ve zorunlu alan kontrolü burada da zorunludur (DB `CHECK` son savunmadır).
- **Data** kategori hiyerarşisi (`parent_id` öz referans) ve ürün bütünlük kısıtlarını uygular.
- **OS** katmanında iki fiziksel varlık vardır: `inventory.db` ve `images/` klasörü. İkisi birlikte yedeklenir.

Bağımlılıklar (`pubspec.yaml`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path: ^1.9.0
  path_provider: ^2.1.0
  image_picker: ^1.0.0
  file_picker: ^8.0.0
  provider: ^6.1.0
  intl: ^0.19.0
  uuid: ^4.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 3. Platform Matrisi

| Konu | Android | Windows | Linux |
|---|---|---|---|
| SQLite motoru | `sqflite` (gömülü) | `sqflite_common_ffi` (`databaseFactoryFfi`, `sqfliteFfiInit()` açılışta) | `sqflite_common_ffi` (aynı) |
| DB dosyası | `<support>/inventory.db` | `<support>/inventory.db` | `<support>/inventory.db` |
| Görsel kökü | `<support>/images/` | `<support>/images/` | `<support>/images/` |
| Görsel kaynağı | Galeri + kamera (`image_picker`) | Dosya seçici (`file_picker`, jpg/jpeg/png/webp) | Dosya seçici (aynı) |
| İzinler | `CAMERA`, API 33+: `READ_MEDIA_IMAGES`, API 32-: `READ_EXTERNAL_STORAGE` (reddedilirse dosya seçiciye dönüş + bilgi metni) | Ek izin yok | Ek izin yok; Snap/Flatpak paketlenirse ev-dizini bildirimi |
| Paketleme | APK / AAB (imzalı) | MSIX veya taşınabilir zip (SQLite FFI ikilisinin pakete gömüldüğü doğrulanır) | deb / tar / AppImage (aynı doğrulama) |
| Kabul | Uçak modunda kurulum + açılış + CRUD | Temiz makinede açılış + CRUD | Temiz makinede açılış + CRUD |

Açılış sırası her platformda aynıdır: `sqfliteFfiInit()` (yalnızca masaüstü) -> destek dizinini çöz -> `images/` dizinini garanti et -> DB aç (`PRAGMA foreign_keys = ON` her bağlantıda) -> `user_version` kontrolü -> yetim dosya taraması (sessiz).

---

## 4. SQLite Şeması (v1)

İlkeler: tek doğruluk kaynağı yerel `.db` dosyasıdır. Tarihler ISO-8601 UTC `TEXT`. Görsel BLOB yasaktır. Tüm yazmalar transaction içindedir. `PRAGMA foreign_keys = ON` her bağlantıda çalıştırılır (SQLite varsayılanı OFF olduğu için). `journal_mode = WAL` önerilir.

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS categories (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL CHECK (length(trim(name)) > 0),
  parent_id   INTEGER NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (parent_id IS NULL OR parent_id != id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_parent_name
  ON categories(parent_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS products (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL CHECK (length(trim(name)) > 0),
  description TEXT NOT NULL DEFAULT '',
  quantity    INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  image_path  TEXT NULL CHECK (
    image_path IS NULL
    OR (image_path NOT LIKE '/%'
        AND image_path NOT LIKE '%..%'
        AND image_path NOT LIKE '%\\%')
  ),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_categories_parent  ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_products_category  ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_name     ON products(name COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_products_created  ON products(created_at DESC);
```

Tasarım notları:

- Kök kategori `parent_id IS NULL` değerlidir. Üst kategori silinirse `ON DELETE CASCADE` tüm alt ağacı temizler.
- `products.category_id` için `ON DELETE RESTRICT` seçilmiştir: içinde ürün olan kategori (veya ürün içeren alt dalı olan kategori) silinemez. Uygulama, silme denemesinde ürün sayısını gösterir ve ürünleri taşımayı/silmeyi ister.
- Aynı ebeveyn altında yinelenen ad `UNIQUE(parent_id, name COLLATE NOCASE)` ile engellenir.
- Kendine ebeveynlik `CHECK` ile engellenir; **derin döngü (A->B->A)** uygulama katmanında engellenir: taşıma/ebeveyn değiştirmede hedef, düğümün kendi alt ağacında olamaz (bellekteki ağaç üzerinde ata kontrolü + test).
- `image_path` göreli olmak zorundadır: mutlak yol (`/...`), üst-dizin (`..`) ve Windows ayracı (`\`) reddedilir. Ayraç her zaman `/` yazılır.
- Negatif stok çift katmanlı engellenir: form validasyonu (`^[0-9]+$`, `>= 0`) + `CHECK(quantity >= 0)`. Azaltma işlemleri koşullu yazılır (`... WHERE id = ? AND quantity >= ?`, etkilenen satır 0 ise yetersiz stok).
- Migration `PRAGMA user_version` ile ileri yönlüdür (downgrade yok). v2 örneği: `ALTER TABLE products ADD COLUMN barcode TEXT NULL` + index + `user_version = 2`, tek transaction içinde.

Hiyerarşik listeleme (alt kategori dahil), aramalı, sıralamalı, sayfalı:

```sql
WITH RECURSIVE subtree(id) AS (
  SELECT :root_id
  UNION ALL
  SELECT c.id FROM categories c JOIN subtree s ON c.parent_id = s.id
)
SELECT p.id, p.name, p.quantity, p.category_id, p.image_path, p.created_at
FROM products p
WHERE (:root_id IS NULL OR p.category_id IN (SELECT id FROM subtree))
  AND (:q = '' OR p.name LIKE '%' || :esc_q || '%' ESCAPE '\'
                COLLATE NOCASE
             OR p.description LIKE '%' || :esc_q || '%' ESCAPE '\'
                COLLATE NOCASE)
ORDER BY
  CASE WHEN :sort = 'name' AND :asc = 1 THEN p.name END COLLATE NOCASE ASC,
  CASE WHEN :sort = 'quantity' THEN p.quantity END DESC,
  p.created_at DESC
LIMIT :limit OFFSET :offset;
```

- `:esc_q` içinde `%`, `_`, `\` kaçışlanır (`\%`, `\_`, `\\`). Türkçe büyük/küçük harf için istemci tarafı `toLowerCase('tr')` normalizasyonu da uygulanır; FTS5 yalnızca kayıt sayısı 10.000+ eşiğinde v2 işi olarak değerlendirilir.
- Liste `LIMIT/OFFSET` ile sayfalanır (varsayılan sayfa 100); toplam için ayrı `COUNT(*)` sorgusu koşar.

---

## 5. Dosya Saklama Mimarisi

```text
<support>/
  inventory.db
  images/
    <uuid>.jpg | <uuid>.png | <uuid>.webp ...
  thumbnails/   (ileride, ayrılmıştır)
  tmp/          (doğrulama öncesi geçici alan)
```

- Veritabanında yalnızca `images/<uuid>.<ext>` saklanır. Mutlak yol asla yazılmaz; tam yol çalışma anında `<support> + relative` ile üretilir.
- Dosya adı her zaman UUID v4 + normalize uzantıdır (küçük harf; izin verilenler: `jpg`, `jpeg`, `png`, `webp`). Kullanıcı dosya adı kullanılmaz, Türkçe karakter sorunu doğmaz.
- Azami boyut 10 MB. Uzantı + boyut + sihirli bayt (magic-bytes: JPEG `FF D8`, PNG `89 50 4E 47`, WebP `RIFF....WEBP`) denetimi `tmp/` aşamasında yapılır; geçersizse geçici dosya silinir ve Türkçe hata gösterilir.
- **Yazma sırası (atomikliğe yakın):** eklemede önce dosyayı `images/` altına kopyala (boyut karşılaştırması yap), sonra transaction içinde `INSERT`; commit başarısız olursa kopyayı geri al. Görsel değiştirmede önce yeniyi kopyala, `UPDATE` commit edildikten sonra eskiyi sil. Silmede önce satırı sil+commit et, sonra dosyayı sil; dosya silme hatası kritik değildir, kayıt `orphan scanner` ile kapatılır.
- **Orphan scanner:** `images/` içeriği ile `image_path` değerleri karşılaştırılır; karşılığı olmayan dosya açılışta (sessiz) ve ayarlardan (raporlu) temizlenir.
- **Kayıp dosya:** `image_path` dolu ama dosya diskte yoksa liste çökmez; kartta monogram/ikon yer tutucu gösterilir.
- Kaynak dosya asla taşınmaz, yalnızca kopyalanır; galerideki orijinal değişmez. `tmp/` her işlem sonunda ve açılışta temizlenir.

---

## 6. UI/UX Sistemi (dark-only, emojisiz, endüstriyel)

Tema jetonları (`lib/theme/app_theme.dart`, `ThemeMode.dark` sabit; açık mod kodu yoktur):

| Jeton | Değer | Kullanım |
|---|---|---|
| `background` | `#0A0A0A` | Scaffold zemini |
| `surface` / `surfaceVariant` | `#141414` / `#1E1E1E` | Kart, diyalog, FAB karşıtı |
| `textPrimary` | `#F5F5F0` | Başlık, birincil metin, FAB zemini |
| `textEmphasis` | `#EAE6DF` | Vurgu metni |
| `border` | `#262626` | Kart/alan çizgisi, ayraç |
| `textSecondary` | `#8E8E93` | Açıklama, kategori yolu, placeholder |
| Rakamlar | `FontFeature.tabularFigures()` | Adet, sayı, tarih (tek aralıklı) |
| İkonlar | Material outlined (ince çizgi): `inventory_2_outlined`, `folder_outlined`, `add`, `edit_outlined`, `delete_outline`, `search`, `close` | Emoji ve dolgulu/renkli sembol yok |
| İşlevsel tonlar (yalnızca durum bildirimi) | `success #9DB89A`, `warning #C9B48A`, `danger #C08A8A` (doygunluğu düşürülmüş, endüstriyel) | Hata/uyarı/düşük-stok vurgusu; zemin/kart/metin renkleri palet dışına çıkmaz |

Ekranlar:

1. **Ana iskelet** (`home_screen.dart`): Android alt bar (Envanter / Kategoriler), masaüstü `NavigationRail` (aynı iki hedef). AppBar: başlık + toplam ürün rozeti (tabular). FAB: bulunduğu sekmeye göre ürün ekleme veya kök kategori ekleme. Masaüstü kısayolu `Ctrl+N`.
2. **Envanter sekmesi** (`inventory_tab.dart`): arama alanı (placeholder `Ürün adı veya açıklama ile ara`, gerçek zamanlı, ~300 ms debounce, temizleme çarpısı), kategori filtresi (breadcrumb `Tümü / Donanım / Bağlantı`, tıklanabilir üst düzeye dönüş + genişletilebilir ağaç, seçili dalda ince sol çizgi, `Filtreyi temizle` metin butonu), sıralama çubuğu (ölçüt: Ad / Stok / Tarih; yön: Artan / Azalan; varsayılan Tarih yeniden-eskite, oturumda hatırlanır), ürün listesi (`product_card.dart`, sayfalı `ListView`), sonuç sayısı (tabular). Boş durum: başlık `Henüz ürün eklenmemiş` veya `Aramanızla eşleşen ürün bulunamadı` + alt metin `FAB üzerinden ilk ürününüzü oluşturun`.
3. **Kategoriler sekmesi** (`categories_tab.dart`): sınırsız derinlikte ağaç (`ExpansionTile`), her düğümde isim + alt-ağaç ürün sayısı (tabular), eylemler: alt kategori ekle, yeniden adlandır, sil. Ürünlü dal silinmek istenirse engelleme diyaloğu (ürün sayısını söyler, ürünleri taşı/sil yönergesi verir). Kök ekleme üstte.
4. **Ürün formu** (`product_form_screen.dart`, ekle+duzenle tek form; mobil tam sayfa, masaüstü 560 dp ortalanmış): görsel seçici (boşken `Görsel seç` + ikon; doluyken önizleme + `Değiştir` / `Kaldır`; masaüstünde yalnızca dosya türü filtresi, boy aşımında `Görsel 10 MB sınırını aşıyor`), isim (zorunlu), açıklama (çok satırlı, min 3 satır, opsiyonel), adet (sayısal alan + `-`/`+` stepper, klavye girişi, negatif reddedilir, 0 geçerli), **n-seviye kategori seçici** (ağaç/breadcrumb picker; yalnızca iki kademe dropdown değildir) + listede sabit **`Kategori Ekle`** eylemi: formu kapatmadan modal açar (`AddCategoryDialog`: isim + üst kategori seçimi, varsayılan = mevcut seçim; kaydetme sonrası yeni kategori listede seçili hale gelir, forma kaldığı yerden devam edilir). Kaydetme: validasyon -> `ImageStore` -> provider -> `SnackBar` (Türkçe).
5. **Onaylı silme** (`dialogs.dart`): sil ikonuna basıldığında doğrudan silme yapılmaz. Başlık `Ürünü sil`, gövde aynen `Bu ürünü envanterden silmek istediğinize emin misiniz?`, butonlar `Vazgeç` / `Sil`. Onayda kayıt + ilişkili dosya temizlenir.

Doğrulama mesajları (Türkçe, emojisiz): `Ürün ismi zorunludur`, `Adet sıfırdan küçük olamaz`, `Adet yalnızca rakam olabilir`, `Kategori seçimi zorunludur`, `Kategori adı zorunludur`, `Bu ad bu düzeyde zaten kullanılıyor`, `Görsel 10 MB sınırını aşıyor`, `Desteklenmeyen dosya türü`.

Hata gösterimi palet içinde kalır: alan altında `textPrimary` hata metni + `error_outline` ikon + `#262626` çerçeveli alan vurgusu; ayırt edilebilirlik için yalnızca durum bildirimlerinde doygunluğu düşürülmüş `danger` tonu kullanılır (zemin/kart/metin renkleri değişmez, yeni canlı renk yoktur). kontrast kemik-beyazı zemin varsayımıyla değil, koyu zemin üzerinde kemik-beyazı metinle sağlanır. Odaklanmada ince kemik-beyazı çerçeve, tüm ikon butonlarda ekran-okuyucu etiketi, `Tab` sırası, `Esc` kapatma, `Enter` birincil eylem.

Denetim ölçütü: arayüzde sıfır emoji (incelemede metin taraması), yalnızca outlined ikon seti, tüm adet/tarih alanlarında `tabularFigures`.

---

## 7. Test ve Kalite Kapıları

- `test/validators_test.dart`: isim boşluğu, adet harf/negatif/boş/geçerli, kategori boşluğu.
- DB testleri: CRUD, negatif stok reddi, `UNIQUE(parent, name)` reddi, döngü engelleme, CASCADE/RESTRICT davranışı, recursive CTE alt-ağaç doğruluğu, `LIMIT/OFFSET` sayfalama.
- `ImageStore` testleri: kopyalama, uzantı/boyut reddi, replace eski-silme, orphan taraması, kayıp-dosya sessizliği.
- Widget testleri: arama filtreleme, sıralama, formdan ayrılmadan kategori ekleme, onay metninin aynen varlığı, silmede dosya temizliği.
- Platform duman testleri: üç hedefte uçak-modu açılış + kabul senaryosu (ağaç kur -> ürün ekle -> ara/filtrele/sırala -> düzenle -> onaylı sil -> yeniden başlatıp bütünlüğü gör).
- Emoji taraması: `grep -rP` ile renkli sembol/emoji denetimi (beklenen: sıfır eşleşme).

---

## 8. Riskler

| Risk | Etki | Önlem |
|---|---|---|
| Masaüstü eklenti olgunluğu | Dosya/kamera farkları | `file_picker` masaüstü ana yol, kamera yok; ince uyumluluk katmanı |
| FFI başlatma sırası / Linux paket bağımlılıkları | Açılışta çökme | Tekil başlatıcı + şema doğrulama + paket içi SQLite gömme doğrulaması |
| Dosya-kayıt tutarsızlığı (crash arası) | Orphan/kayıp dosya | Sıralı yazma kuralı + açılış orphan taraması + kayıp-dosyada yer tutucu |
| Şema evrimi | Migration hatası | İleri-yönlü sürümlü script + transaction + test |
| Palet kısıtı (hata rengi yok) | Hata fark edilebilirliği | İkon + metin + çerçeve vurgusu, kontrast ölçümü |

---

## 9. Dosya Haritası (gerçeklenen)

```text
pubspec.yaml
analysis_options.yaml
lib/main.dart
lib/theme/app_theme.dart
lib/models/category.dart
lib/models/product.dart
lib/db/app_database.dart
lib/services/image_store.dart
lib/utils/validators.dart
lib/providers/inventory_provider.dart
lib/screens/home_screen.dart
lib/screens/inventory_tab.dart
lib/screens/categories_tab.dart
lib/screens/product_form_screen.dart
lib/widgets/product_card.dart
lib/widgets/category_filter_tree.dart
lib/widgets/dialogs.dart
lib/widgets/app_icons.dart
test/validators_test.dart
```
