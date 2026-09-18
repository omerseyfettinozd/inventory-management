// Inventory Management — envanter durum yonetimi (ChangeNotifier).
//
// Bu katman, SQLite veritabani ([AppDatabase]) ile dosya sistemi gorsel
// deposu ([ImageStore]) arasindaki koordinasyonu tek noktada toplar:
// - Kategori ve urun listelerinin bellege alinmasi ([loadAll]).
// - Envanter ekraninin arama / siralama durumu
//   ([searchQuery], [sortField], [sortAsc]), favoriler bolumunun bagimsiz
//   siralama durumu ([favSortField], [favSortAsc]) ve turetilmis
//   gorunumler ([filteredProducts], [favoriteProducts]).
//   ([selectedCategoryId] korunur ancak Envanter ekrani artik kullanmaz.)
// - Urun gorsellerinin yasam dongusu: eklemede kopyalama, guncellemede
//   eski dosyanin temizligi, silmede kayit + dosya temizligi.
// Tum kullaniciya donuk hata mesajlari Turkce ve emojisizdir.

import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:inventory_management/db/app_database.dart';
import 'package:inventory_management/services/image_store.dart';
import 'package:inventory_management/utils/validators.dart';

/// Filtre / arama / siralama durumunu tutan ve veritabani yazmalarini
/// gorsel dosya temizligi ile birlikte yurutun merkezi durum nesnesi.
///
/// Kullanim:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => InventoryProvider()..loadAll(),
///   child: const InventoryScreen(),
/// )
/// ```
class InventoryProvider extends ChangeNotifier {
  /// [database] / [images] verilmezse uretim singletonlari kullanilir.
  /// Testlerde bellek ici (in-memory) veritabani ve gecici dizinli
  /// [ImageStore] enjekte edilebilir.
  InventoryProvider({
    AppDatabase? database,
    ImageStore? images,
  })  : _db = database ?? AppDatabase(),
        _images = images ?? ImageStore();

  final AppDatabase _db;
  final ImageStore _images;

  List<Category> _categories = <Category>[];
  List<Product> _products = <Product>[];

  /// Secili kategori filtresi. `null` tum urunler anlamina gelir.
  int? _selectedCategoryId;

  /// Urun adi + aciklamaya uygulanan gercek zamanli arama metni.
  String _searchQuery = '';

  /// Siralama alani. Envanter ekrani ad / adet / tarih secer.
  ProductSortField _sortField = ProductSortField.name;

  /// `true` artan, `false` azalan siralama.
  bool _sortAsc = true;

  /// Favoriler bolumunun bagimsiz siralama alani.
  ProductSortField _favSortField = ProductSortField.name;

  /// Favoriler bolumunun bagimsiz siralama yonu (`true` artan).
  bool _favSortAsc = true;

  bool _isLoading = false;

  /// Son islemde olusan Turkce hata mesaji. Hata yoksa `null`.
  String? _lastError;

  // -----------------------------------------------------------------
  // Salt okunur gorunumler
  // -----------------------------------------------------------------

  /// Tum kategoriler (ada gore sirali).
  List<Category> get categories => List<Category>.unmodifiable(_categories);

  /// Tum urunler (ham liste; filtreli gorunum icin [filteredProducts]).
  List<Product> get products => List<Product>.unmodifiable(_products);

  /// Kategori agaci (kok dugumler). Klasor hiyerarsisi bu agactan cizilir.
  List<CategoryNode> get categoryTree => _db.buildTree(_categories);

  /// Secili kategori kimligi. `null` tum urunler anlamina gelir.
  int? get selectedCategoryId => _selectedCategoryId;

  /// Ham arama metni (kirpilmamis).
  String get searchQuery => _searchQuery;

  /// Aktif siralama alani.
  ProductSortField get sortField => _sortField;

  /// [sortField] ile ayni degeri donen takma ad.
  /// Veritabani katmanindaki `sortBy` adlandirmasiyla uyum icindir.
  ProductSortField get sortBy => _sortField;

  /// Artan siralama mi?
  bool get sortAsc => _sortAsc;

  /// Favoriler bolumunun siralama alani.
  ProductSortField get favSortField => _favSortField;

  /// Favoriler bolumu artan sirali mi?
  bool get favSortAsc => _favSortAsc;

  /// Yukleme / yazma islemi suruyor mu?
  bool get isLoading => _isLoading;

  /// Son hatanin Turkce mesaji. Hata yoksa `null`.
  String? get lastError => _lastError;

  /// Filtre + arama + siralama uygulanmis urun listesi.
  ///
  /// - Kategori filtresi alt kategori agacini kapsar: bir kategori
  ///   secildiginde o kategorinin tum alt kategorilerindeki urunler de
  ///   listelenir.
  /// - Arama buyuk/kucuk harf duyarsizdir, ad ve aciklamada gecer.
  /// - Siralama [sortField] + [sortAsc] degerlerine gore yapilir.
  List<Product> get filteredProducts {
    final Set<int>? allowed = _allowedCategoryIds();
    final String needle = _fold(_searchQuery.trim());

    final List<Product> result = _products.where((Product p) {
      if (allowed != null && !allowed.contains(p.categoryId)) {
        return false;
      }
      if (needle.isNotEmpty) {
        final String haystack = '${_fold(p.name)}\n${_fold(p.description)}';
        if (!haystack.contains(needle)) {
          return false;
        }
      }
      return true;
    }).toList();

    result.sort(_compareProducts);
    return result;
  }

  /// Arama uygulanmis + favori siralama duzenine gore sirali favoriler.
  ///
  /// Arama metni ana listeyle ayni sekilde (ad + aciklama, buyuk/kucuk
  /// harf duyarsiz) uygulanir; siralama yalnizca favori bolumunun
  /// [favSortField] + [favSortAsc] degerlerine gore yapilir.
  List<Product> get favoriteProducts {
    final String needle = _fold(_searchQuery.trim());

    final List<Product> result = _products.where((Product p) {
      if (!p.isFavorite) {
        return false;
      }
      if (needle.isNotEmpty) {
        final String haystack = '${_fold(p.name)}\n${_fold(p.description)}';
        if (!haystack.contains(needle)) {
          return false;
        }
      }
      return true;
    }).toList();

    result.sort(
      (Product a, Product b) =>
          _compareWith(a, b, _favSortField, _favSortAsc),
    );
    return result;
  }

  // -----------------------------------------------------------------
  // Filtre / arama / siralama ayarlari
  // -----------------------------------------------------------------

  /// Arama metnini gunceller.
  void setSearch(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  /// Kategori filtresini degistirir. `null` filtreyi kaldirir (tumu).
  void setCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) {
      return;
    }
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  /// Siralama alani ve yonunu gunceller.
  void setSort(ProductSortField field, [bool ascending = true]) {
    if (_sortField == field && _sortAsc == ascending) {
      return;
    }
    _sortField = field;
    _sortAsc = ascending;
    notifyListeners();
  }

  /// Favoriler bolumunun siralama alani ve yonunu gunceller.
  /// Ana listenin siralama durumu etkilenmez.
  void setFavSort(ProductSortField field, [bool ascending = true]) {
    if (_favSortField == field && _favSortAsc == ascending) {
      return;
    }
    _favSortField = field;
    _favSortAsc = ascending;
    notifyListeners();
  }

  /// Tum filtreleri sifirlar: kategori, arama ve siralama
  /// (favori bolumu siralama durumu dahil).
  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = '';
    _sortField = ProductSortField.name;
    _sortAsc = true;
    _favSortField = ProductSortField.name;
    _favSortAsc = true;
    notifyListeners();
  }

  /// [lastError] degerini temizler.
  void clearError() {
    if (_lastError == null) {
      return;
    }
    _lastError = null;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Yukleme
  // -----------------------------------------------------------------

  /// Tum kategorileri ve urunleri bellege alir.
  ///
  /// Basarida `true`, hata durumunda `false` doner; hata mesaji
  /// [lastError] alaninda Turkce olarak tutulur.
  Future<bool> loadAll() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final List<Category> cats = await _db.getAllCategories();
      final List<Product> prods = await _db.queryProducts();
      _categories = cats;
      _products = prods;
      // Secili kategori artik mevcut degilse filtreyi dusur.
      if (_selectedCategoryId != null &&
          _categories.every((Category c) => c.id != _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
      return true;
    } catch (e) {
      _lastError = 'Veriler yüklenemedi: ${_plainError(e)}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------
  // Kategori islemleri
  // -----------------------------------------------------------------

  /// Yeni kategori (veya alt kategori) olusturur.
  ///
  /// Basarida yeni satir kimligini, dogrulama / veritabani hatasinda
  /// `null` doner; hata mesaji [lastError] alanindadir.
  Future<int?> addCategory(String name, {int? parentId}) async {
    final String? invalid = Validators.validateCategoryName(name);
    if (invalid != null) {
      _lastError = invalid;
      notifyListeners();
      return null;
    }
    _lastError = null;
    try {
      final int id =
          await _db.insertCategory(name: name.trim(), parentId: parentId);
      _categories = await _db.getAllCategories();
      notifyListeners();
      return id;
    } catch (e) {
      _lastError = 'Kategori eklenemedi: ${_plainError(e)}';
      notifyListeners();
      return null;
    }
  }

  /// Kategoriyi yeniden adlandirir.
  ///
  /// Basarida `true`, dogrulama / veritabani hatasinda `false` doner;
  /// hata mesaji [lastError] alanindadir.
  Future<bool> renameCategory(int id, String name) async {
    final String? invalid = Validators.validateCategoryName(name);
    if (invalid != null) {
      _lastError = invalid;
      notifyListeners();
      return false;
    }
    _lastError = null;
    try {
      await _db.updateCategoryName(id, name.trim());
      _categories = await _db.getAllCategories();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Kategori yeniden adlandırılamadı: ${_plainError(e)}';
      notifyListeners();
      return false;
    }
  }

  /// Kategoriyi siler.
  ///
  /// Kategori veya alt kategorilerinde urun varsa silme engellenir ve
  /// Turkce mesaj iceren [StateError] firlatilir (ayrica [lastError]
  /// alanina yazilir). Basarida `true` doner.
  Future<bool> deleteCategory(int id) async {
    _lastError = null;
    try {
      final int count = await _db.countProductsInCategory(
        id,
        includeSubtree: true,
      );
      if (count > 0) {
        final String message =
            'Bu kategori silinemez: alt kategoriler dahil $count ürün bulunuyor. '
            'Önce ürünleri taşıyın veya silin.';
        _lastError = message;
        notifyListeners();
        throw StateError(message);
      }
      await _db.deleteCategory(id);
      _categories = await _db.getAllCategories();
      _products = await _db.queryProducts();
      if (_selectedCategoryId != null &&
          _categories.every((Category c) => c.id != _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
      notifyListeners();
      return true;
    } on StateError catch (e) {
      // Urun engeli zaten Turkce kuruldu; diger StateError durumlari
      // (kayit yok vb.) burada Turkcelestirilir.
      if (_lastError == null || _lastError!.isEmpty) {
        _lastError = 'Kategori silinemedi: ${_plainError(e)}';
        notifyListeners();
      }
      rethrow;
    } catch (e) {
      _lastError = 'Kategori silinemedi: ${_plainError(e)}';
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------
  // Urun islemleri
  // -----------------------------------------------------------------

  /// Yeni urun olusturur. [imageFile] verilirse once uygulamaya kopyalanir.
  ///
  /// Basarida yeni satir kimligini, hata durumunda `null` doner.
  Future<int?> addProduct({
    required String name,
    String description = '',
    required int quantity,
    required int categoryId,
    File? imageFile,
  }) async {
    final String? invalid = _validateProductInput(
      name: name,
      description: description,
      quantity: quantity,
      categoryId: categoryId,
    );
    if (invalid != null) {
      _lastError = invalid;
      notifyListeners();
      return null;
    }
    _lastError = null;

    String? relative;
    if (imageFile != null) {
      try {
        await _ensureImages();
        relative = await _images.saveImage(imageFile);
      } catch (e) {
        _lastError = 'Görsel kaydedilemedi: ${_plainError(e)}';
        notifyListeners();
        return null;
      }
    }

    try {
      final int id = await _db.insertProduct(
        name: name.trim(),
        description: description,
        quantity: quantity,
        categoryId: categoryId,
        imagePath: relative,
      );
      _products = await _db.queryProducts();
      notifyListeners();
      return id;
    } catch (e) {
      // Yetim dosya birakmamak icin kopyalanan gorsel geri alinir.
      await _images.deleteByRelative(relative);
      _lastError = 'Ürün eklenemedi: ${_plainError(e)}';
      notifyListeners();
      return null;
    }
  }

  /// Urunu gunceller. Yalnizca verilen alanlar degistirilir.
  ///
  /// - [newImageFile] verilirse gorsel degistirilir; veritabani yazimi
  ///   basarili olursa eski dosya diskten silinir.
  /// - [clearImage] `true` ise mevcut gorsel kaldirilir.
  /// Basarida `true`, hata durumunda `false` doner.
  Future<bool> updateProduct({
    required int id,
    String? name,
    String? description,
    int? quantity,
    int? categoryId,
    File? newImageFile,
    bool clearImage = false,
  }) async {
    _lastError = null;
    final Product? existing = await _db.getProductById(id);
    if (existing == null) {
      _lastError = 'Ürün bulunamadı (id: $id).';
      notifyListeners();
      return false;
    }

    final String nextName = name ?? existing.name;
    final String nextDescription = description ?? existing.description;
    final int nextQuantity = quantity ?? existing.quantity;
    final int nextCategoryId = categoryId ?? existing.categoryId;

    final String? invalid = _validateProductInput(
      name: nextName,
      description: nextDescription,
      quantity: nextQuantity,
      categoryId: nextCategoryId,
    );
    if (invalid != null) {
      _lastError = invalid;
      notifyListeners();
      return false;
    }
    if (newImageFile != null && clearImage) {
      _lastError = 'Aynı işlemde hem yeni görsel hem görsel kaldırma seçilemez.';
      notifyListeners();
      return false;
    }

    final String? oldRelative = existing.imagePath;
    String? savedRelative;
    if (newImageFile != null) {
      try {
        await _ensureImages();
        savedRelative = await _images.saveImage(newImageFile);
      } catch (e) {
        _lastError = 'Görsel kaydedilemedi: ${_plainError(e)}';
        notifyListeners();
        return false;
      }
    }

    try {
      await _db.updateProduct(
        id: id,
        name: name,
        description: description,
        quantity: quantity,
        categoryId: categoryId,
        imagePath: savedRelative,
        clearImage: clearImage,
      );
    } catch (e) {
      // Veritabani yazimi basarisizsa yeni kopyalanan dosya temizlenir,
      // eski gorsel korunur.
      await _images.deleteByRelative(savedRelative);
      _lastError = 'Ürün güncellenemedi: ${_plainError(e)}';
      notifyListeners();
      return false;
    }

    // Veritabani yazimi basarili: artik gereksiz olan dosya temizlenir.
    // Depo baslatilamazsa dosya yetim kalir; aclistaki tarama kapatir.
    // Liste tazeleme her durumda yapilir (metin duzenlemesi dosya
    // sorunundan etkilenmez).
    try {
      await _ensureImages();
    } catch (_) {
      _products = await _db.queryProducts();
      notifyListeners();
      return true;
    }
    if (savedRelative != null) {
      await _images.deleteByRelative(oldRelative);
    } else if (clearImage) {
      await _images.deleteByRelative(oldRelative);
    }

    _products = await _db.queryProducts();
    notifyListeners();
    return true;
  }

  /// Urunu siler; kaydin yani sira iliskili yerel gorsel dosyasini da
  /// diskten temizler. Basarida `true`, hata durumunda `false` doner.
  ///
  /// Kayit silindikten sonra dosya temizligi en iyi cabadir: depo
  /// baslatilamazsa dosya yetim kalir (acilis taramasi kapatir) ancak
  /// liste yine tazelenir ve `true` doner.
  Future<bool> deleteProduct(int id) async {
    _lastError = null;
    late final Product deleted;
    try {
      deleted = await _db.deleteProduct(id);
    } catch (e) {
      _lastError = 'Ürün silinemedi: ${_plainError(e)}';
      notifyListeners();
      return false;
    }
    try {
      await _ensureImages();
      await _images.deleteByRelative(deleted.imagePath);
    } catch (_) {
      // Bilincli olarak sessiz gecilir (bkz. dokumantasyon).
    }
    _products = await _db.queryProducts();
    notifyListeners();
    return true;
  }

  /// Urunun favori isaretini tersine cevirir ve listeyi tazeler.
  ///
  /// Basarida yeni favori durumunu (`true` favori) dondurur; hata
  /// durumunda `null` doner ve Turkce mesaj [lastError] alanindadir.
  Future<bool?> toggleFavorite(int id) async {
    _lastError = null;
    try {
      final bool next = await _db.toggleFavorite(id);
      _products = await _db.queryProducts();
      notifyListeners();
      return next;
    } catch (e) {
      _lastError = 'Favori güncellenemedi: ${_plainError(e)}';
      notifyListeners();
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Yardimcilar
  // -----------------------------------------------------------------

  /// Goruntu deposunun baslatildigindan emin olur.
  ///
  /// [ImageStore] tembel de baslatilabilir; `main.dart` on-yuklemesi
  /// basarisiz olursa ilk dosya isleminden once burada tamamlanir.
  /// Boylece `saveImage`/`deleteByRelative` asla `StateError` atmaz.
  Future<void> _ensureImages() async {
    if (!_images.isInitialized) {
      await _images.init();
    }
  }

  /// Kimlige gore kategori bulur, yoksa `null` doner.
  Category? categoryById(int id) {
    for (final Category c in _categories) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  /// Secili kategorinin alt agacindaki kimlik kumesini bellek ici hesaplar.
  ///
  /// Secim yoksa `null` (filtre yok) doner. Derinlikten bagimsiz genislik
  /// oncelikli dolasma kullanir; cevrimli veriye karsi ziyaret kumesine
  /// dayanir.
  Set<int>? _allowedCategoryIds() {
    final int? selected = _selectedCategoryId;
    if (selected == null) {
      return null;
    }
    final Map<int, List<int>> childrenOf = <int, List<int>>{};
    for (final Category c in _categories) {
      final int? parent = c.parentId;
      if (parent != null) {
        (childrenOf[parent] ??= <int>[]).add(c.id);
      }
    }
    final Set<int> allowed = <int>{selected};
    final List<int> queue = <int>[selected];
    while (queue.isNotEmpty) {
      final int current = queue.removeLast();
      for (final int child in childrenOf[current] ?? const <int>[]) {
        if (allowed.add(child)) {
          queue.add(child);
        }
      }
    }
    return allowed;
  }

  /// Turkce duyarsiz arama katlamasi.
  ///
  /// `toLowerCase` tek basina yeterli degildir: "İ" harfi "i" + birlesen
  /// nokta (U+0307) olur, "ı" ise oldugu gibi kalir. Boylece "yildiz"
  /// yazinca "Yıldız" bulunamazdi. Bu yardimci iki tarafi da (arama metni
  /// + urun adi/aciklamasi) ayni sekle indirger.
  String _fold(String s) => s
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll('ı', 'i');

  int _compareProducts(Product a, Product b) {
    return _compareWith(a, b, _sortField, _sortAsc);
  }

  int _compareWith(
    Product a,
    Product b,
    ProductSortField field,
    bool ascending,
  ) {
    int result;
    switch (field) {
      case ProductSortField.name:
        result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (result == 0) {
          result = a.id.compareTo(b.id);
        }
      case ProductSortField.quantity:
        result = a.quantity.compareTo(b.quantity);
        if (result == 0) {
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      case ProductSortField.createdAt:
        result = a.createdAt.compareTo(b.createdAt);
        if (result == 0) {
          result = a.id.compareTo(b.id);
        }
      case ProductSortField.updatedAt:
        result = a.updatedAt.compareTo(b.updatedAt);
        if (result == 0) {
          result = a.id.compareTo(b.id);
        }
    }
    return ascending ? result : -result;
  }

  String? _validateProductInput({
    required String name,
    required String description,
    required int quantity,
    required int categoryId,
  }) {
    return Validators.validateProductName(name) ??
        Validators.validateDescription(description) ??
        (quantity < 0 ? 'Adet negatif olamaz.' : null) ??
        (quantity > 9999999 ? 'Adet en fazla 9999999 olabilir.' : null) ??
        Validators.validateCategoryId(categoryId);
  }

  /// Istisna / hata nesnesinden kullaniciya gosterilebilir metin cikarir.
  String _plainError(Object e) {
    if (e is StateError || e is ArgumentError) {
      final String text = e.toString();
      final int colon = text.indexOf(':');
      if (colon >= 0 && colon + 1 < text.length) {
        return text.substring(colon + 1).trim();
      }
      return text;
    }
    // ImageStoreException bildirimi zaten Turkce ve tektir.
    final String text = e.toString();
    const String prefix = 'ImageStoreException: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length).trim();
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception', '')
        .trim();
  }
}
