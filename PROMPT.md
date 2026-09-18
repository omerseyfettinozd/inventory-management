# PROMPT: Inventory Management Project

```markdown
<TASK>
Windows, Linux ve Android platformlarında yerel çalışan, çevrimdışı öncelikli (offline-first) "Inventory Management" adlı envanter yönetim uygulamasını geliştir. Projeye ait tüm dökümantasyon, planlar ve kaynak kodları `/home/chaple/Belgeler/Inventory Managment/` dizininde oluşturulacaktır.
</TASK>

<EXECUTION_ORDER>
1. MIMARI BELGESI: Uygulamanın hangi teknoloji yığını (Cross-platform: Flutter/Dart önerilir), yerel veritabanı yapısı (SQLite) ve dosya saklama mimarisi üzerine kurulacağını açıklayan teknik dökümanı hazırla.
2. FAZ PLANI: Projenin sıfırdan tamamlanmasına kadar izlenecek faz bazlı (Phase 1, Phase 2...) geliştirme yol haritasını oluştur.
3. UYGULAMA GELİŞTİRME: Yol haritasına sadık kalarak kaynak kodları ve platform yapılandırmalarını yaz.
</EXECUTION_ORDER>

<SYSTEM_REQUIREMENTS>
- Hedef Platformlar: Windows, Linux, Android (Tek kod tabanı).
- Veri Depolama: Yerel SQLite (İnternet bağlantısı gerektirmeyen, ACID uyumlu).
- Dosya/Görsel Yönetimi: Ürün fotoğrafları veritabanına binary kaydedilmeyecek; işletim sisteminin güvenli uygulama veri klasörüne kopyalanıp veritabanında göreceli dosya yolu (relative path) saklanacaktır.
</SYSTEM_REQUIREMENTS>

<FUNCTIONAL_SPECIFICATIONS>
1. Kategori Mimarisi (Hiyerarşik Klasör Sistemi):
   - Kategoriler ve alt kategoriler kullanıcı tarafından dinamik olarak oluşturulacaktır.
   - Klasör/alt klasör mantığında (self-referencing parent_id) hiyerarşik ağaç yapısına sahip olacaktır.
   - Kategori oluşturma işlemi, ürün ekleme ve düzenleme ekranındaki kategori seçme alanından ayrılmadan, oradaki "Kategori Ekle" butonu ile anlık olarak modal içinde isim girilerek yapılabilmelidir.

2. Ürün Ekleme:
   - Form Alanları: Ürün Görseli (Dosya seçici/kamera), Ürün İsmi (Metin), Açıklama (Çok satırlı metin), Adet (Pozitif tam sayı), Kategori ve Alt Kategori seçimi.
   - Doğrulama (Validation): Zorunlu alan kontrolleri ve negatif stok engelleme.

3. Envanter Ekranı (Inventory Tab):
   - Tüm kayıtlı ürünlerin listelendiği ana ekran.
   - Klasör hiyerarşisine göre kategori/alt kategori filtreleme.
   - Ürün adı ve açıklamasına göre gerçek zamanlı arama.
   - Stoğa, ada ve tarihe göre sıralama.

4. Düzenleme:
   - Her ürün satırında/kartında düzenleme tetikleyicisi.
   - Form üzerinden ürünün görseli, ismi, açıklaması, adedi ve kategori/alt kategori konumu dahil tüm alanlarının güncellenebilmesi.

5. Onaylı Silme:
   - Silme butonuna basıldığında doğrudan silme yapılmayacaktır.
   - "Bu ürünü envanterden silmek istediğinize emin misiniz?" onay diyaloğu (Confirmation Modal) açılacaktır.
   - Onay sonrası ürün kaydı ve ilişkili yerel görsel dosyası temizlenecektir.
</FUNCTIONAL_SPECIFICATIONS>

<UI_UX_CONSTRAINTS>
- Tema: SADECE KARANLIK MOD (Dark Mode Only). Açık mod olmayacaktır.
- Renk Paleti:
  - Zemin & Kartlar: Saf / Grafit Siyah (#0A0A0A, #141414, #1E1E1E)
  - Metinler & Vurgular: Kemik Beyazı (Bone White - #F5F5F0 / #EAE6DF)
  - Çizgiler & Kenarlıklar: Koyu Gri (#262626)
  - İkincil Metinler: Nötr Gri (#8E8E93)
- NEGATİF KISITLAMA (KESİN KURAL):
  - Arayüzde EMOJİ KESİNLİKLE KULLANILMAYACAKTIR.
  - Gayriciddi, süsleyici veya renkli semboller KESİNLİKLE BULUNMAYACAKTIR.
  - Yalnızca endüstriyel standartlarda, minimalist, geometrik ve ince hatlı (stroke-based) vektörel ikonlar veya salt tipografik metinler kullanılacaktır.
  - Rakamlar için tek aralıklı (tabular/monospace) hizalama kullanılacaktır.
</UI_UX_CONSTRAINTS>
```
