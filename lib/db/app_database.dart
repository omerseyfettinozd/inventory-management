// Inventory Management — yerel SQLite veritabani katmani.
//
// Platformlar: Windows, Linux, Android (tek kod tabani).
// - Android: sqflite; Windows/Linux: sqflite_common_ffi (acilista sqfliteFfiInit).
// - Veritabani dosyasi tum platformlarda getApplicationSupportDirectory()
//   altindadir (tek kok): <support>/inventory.db
// Gorseller veritabanina binary yazilmaz; uygulama veri klasoru altindaki
// `images/` dizinine kopyalanir, veritabaninda yalnizca goreceli yol
// (`image_path`, orn. `images/<uuid>.jpg`) saklanir.
// Kategori silme: categories CASCADE (alt agac), products RESTRICT
// (icinde urun olan dal silinemez).
// Tum hata mesajlari Turkcedir. Tarih alanlari ISO8601 metin olarak tutulur.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// Android'de `databaseFactory` varsayilani (platform kanali) bu paketten
// gelir; ffi yalnizca masaustunde secilir. Adlar ffi ile cakissa da
// import bilerek korunur.
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Veritabani dosya adi.
const String kDatabaseFileName = 'inventory.db';

/// Veritabani surumu.
const int kDatabaseVersion = 2;

/// Uygulama veri klasoru altinda gorsellerin saklandigi goreceli dizin.
const String kImagesDirName = 'images';

/// Urun listesi siralama alanlari.
enum ProductSortField {
  /// Urun adina gore (buyuk/kucuk harf duyarsiz).
  name,

  /// Stok adedine gore.
  quantity,

  /// Olusturulma tarihine gore.
  createdAt,

  /// Son guncellenme tarihine gore.
  updatedAt,
}

/// Kategori satiri.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.parentId,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id']! as int,
      name: map['name']! as String,
      parentId: map['parent_id'] as int?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Hiyerarsik agac dugumu: bir kategori ve alt kategorileri.
class CategoryNode {
  CategoryNode(this.category, [List<CategoryNode>? children])
      : children = children ?? <CategoryNode>[];

  final Category category;
  final List<CategoryNode> children;
}

/// Urun satiri.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.categoryId,
    required this.imagePath,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int quantity;
  final int categoryId;

  /// Goreceli gorsel yolu (orn. `images/<uuid>.jpg`). Gorsel yoksa null.
  final String? imagePath;

  /// Favori isareti (`is_favorite` sutunu, 0/1).
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id']! as int,
      name: map['name']! as String,
      description: (map['description'] as String?) ?? '',
      quantity: map['quantity']! as int,
      categoryId: map['category_id']! as int,
      imagePath: map['image_path'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) != 0,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'category_id': categoryId,
      'image_path': imagePath,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Uygulamanin yerel SQLite veritabani.
///
/// Singleton olarak kullanilir:
///
/// ```dart
/// final db = AppDatabase();
/// final urunler = await db.sortedList(sortBy: ProductSortField.name);
/// ```
class AppDatabase {
  factory AppDatabase() => _instance;

  AppDatabase._internal();

  static final AppDatabase _instance = AppDatabase._internal();

  Database? _db;
  bool _ffiInitialized = false;

  /// Devam eden acilis. Eszamanli `open()` cagrilari ayni Future'i
  /// paylasir; ayni dosya iki kez acilmaz.
  Future<Database>? _openFuture;

  /// Bellek-ici test kancasi. Uretimde her zaman `null`dir; doluyken
  /// dosya yolu cozumu atlanir (`path_provider` cagrilmaz).
  String? _testPathOverride;

  /// Testler icin dosya yolu gecersiz kilir (orn. [inMemoryDatabasePath]).
  /// Uretim davranisini degistirmez; varsayilan `null`dir.
  @visibleForTesting
  void setTestPathOverride(String path) {
    _testPathOverride = path;
  }

  /// Test gecersiz kilmasini kaldirir.
  @visibleForTesting
  void clearTestPathOverride() {
    _testPathOverride = null;
  }

  /// Acik veritabani. Ilk erisimde olusturulur/acilir.
  Future<Database> get database async {
    final Database? current = _db;
    if (current != null && current.isOpen) {
      return current;
    }
    return open();
  }

  /// Veritabani dosyasinin tam yolunu cozumler.
  ///
  /// Mimari karar (tek kok): tum platformlarda
  /// `getApplicationSupportDirectory()` kullanilir, boylece tasma ve
  /// kullanici-adi degisimine dayanikli tek konum elde edilir.
  Future<String> resolveDatabasePath() async {
    final String? override = _testPathOverride;
    if (override != null) {
      return override;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _ensureFfi();
    }
    final Directory support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    return p.join(support.path, kDatabaseFileName);
  }

  /// Veritabanini acar (gerekirse olusturur). Idempotent calisir.
  ///
  /// Eszamanli cagrilara karsi tek ucan acilis paylasilir: ikinci cagri
  /// ayni Future'i bekler, ayni dosya iki kez acilmaz. Boylece Linux/FFI
  /// dosya kilidine takilan cift `openDatabase` yarisi kokten kalkar.
  Future<Database> open() async {
    final Database? current = _db;
    if (current != null && current.isOpen) {
      return current;
    }
    final Future<Database>? pending = _openFuture;
    if (pending != null) {
      return pending;
    }
    final Future<Database> future = _openLocked();
    _openFuture = future;
    try {
      return await future;
    } finally {
      _openFuture = null;
    }
  }

  /// Tek acilis islemi. [open] tarafindan serilestirilir.
  Future<Database> _openLocked() async {
    final String? override = _testPathOverride;
    if (override != null) {
      // Test kancasi: dosya yolu cozumu ve platform dali atlanir.
      _ensureFfi();
      _db = await databaseFactoryFfi.openDatabase(
        override,
        options: OpenDatabaseOptions(
          version: kDatabaseVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
      return _db!;
    }
    // FFI secimi factory okumadan ONCE yapilir; aksi halde masaustunde
    // yanlis (platform kanali) factory okunurdu.
    if (Platform.isAndroid || Platform.isIOS) {
      final String dbPath = await resolveDatabasePath();
      _db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: kDatabaseVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
      return _db!;
    }
    // Windows / Linux (/macOS): FFI destegi zorunludur.
    _ensureFfi();
    final DatabaseFactory factory = databaseFactoryFfi;
    final String dbPath = await resolveDatabasePath();
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kDatabaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return _db!;
  }

  /// Acik baglantiyi kapatir.
  Future<void> close() async {
    final Database? current = _db;
    _db = null;
    if (current != null && current.isOpen) {
      await current.close();
    }
  }

  void _ensureFfi() {
    if (_ffiInitialized) {
      return;
    }
    // Dikkat: sqflite'in global `databaseFactory` okuyucusu masaustunde
    // henuz atama yapilmamissa `StateError` firlatir; bu yuzden "zaten FFI
    // mi?" diye global OKUNMAZ, yalnizca yerel bayrak kullanilir.
    // main.dart acilista `sqfliteFfiInit()` cagirmis olabilir; cift cagri
    // uretimde zararsizdir (eski davranis aynen korunur).
    sqfliteFfiInit();
    // FFI kullanilan platformlarda global factory de FFI olmalidir,
    // aksi halde sqflite yardimcilari yanlis baglantiyi kullanir.
    databaseFactory = databaseFactoryFfi;
    _ffiInitialized = true;
  }

  Future<void> _onConfigure(Database db) async {
    // Yabanci anahtar veovers cascade silme davranisi icin sarttir.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  parent_id INTEGER NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (parent_id IS NULL OR parent_id != id)
)''');
    await db.execute('''
CREATE UNIQUE INDEX uq_categories_parent_name
  ON categories(parent_id, name COLLATE NOCASE)''');
    await db.execute('''
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  description TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
  image_path TEXT NULL CHECK (
    image_path IS NULL
    OR (image_path NOT LIKE '/%'
        AND image_path NOT LIKE '%..%'
        AND image_path NOT LIKE '%\\%')
  ),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
)''');
    await db.execute(
      'CREATE INDEX idx_categories_parent ON categories(parent_id)',
    );
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX idx_products_created ON products(created_at DESC)',
    );
  }

  /// Ileri yonlu migration iskeleti (dusurme yok).
  ///
  /// - v2: `products.is_favorite` sutunu (mevcut satirlar 0 alir, veri
  ///   kaybi olmaz).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE products '
        'ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // -----------------------------------------------------------------
  // Kategori CRUD
  // -----------------------------------------------------------------

  /// Yeni kategori olusturur, satir kimligini dondurur.
  ///
  /// [parentId] verilirse alt kategori olarak olusturulur; verilen ust
  /// kategori mevcut degilse [StateError] firlatir.
  Future<int> insertCategory({
    required String name,
    int? parentId,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Kategori adi bos olamaz.');
    }
    final Database db = await database;
    if (parentId != null) {
      final Category? parent = await getCategoryById(parentId);
      if (parent == null) {
        throw StateError('Ust kategori bulunamadi (id: $parentId).');
      }
    }
    return db.insert('categories', <String, Object?>{
      'name': trimmed,
      'parent_id': parentId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Kategori adini gunceller. Kayit yoksa [StateError] firlatir.
  Future<void> updateCategoryName(int id, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Kategori adi bos olamaz.');
    }
    final Database db = await database;
    final int count = await db.update(
      'categories',
      <String, Object?>{'name': trimmed},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (count == 0) {
      throw StateError('Kategori bulunamadi (id: $id).');
    }
  }

  /// Kategoriyi siler.
  ///
  /// - Alt kategoriler `ON DELETE CASCADE` ile birlikte silinir.
  /// - Urunler CASCADE ile silinmez: dalda (kendisi dahil) urun varsa
  ///   `ON DELETE RESTRICT` devreye girer ve Turkce [StateError] firlatilir.
  ///   Cagiran katman once urunleri tasimali veya silmelidir.
  /// Kayit yoksa [StateError] firlatir.
  Future<void> deleteCategory(int id) async {
    final Database db = await database;
    try {
      final int count = await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      if (count == 0) {
        throw StateError('Kategori bulunamadi (id: $id).');
      }
    } on DatabaseException catch (e) {
      // Kurulu sqflite surumunde FK yardimcisi yok; ileti eslesmesi
      // surumler arasi tasinabilir olandir (SQLITE_CONSTRAINT_FOREIGNKEY).
      if (e.toString().contains('FOREIGN KEY')) {
        throw StateError(
          'Bu kategori silinemez: alt kategoriler dahil ürün bulunuyor. '
          'Önce ürünleri taşıyın veya silin.',
        );
      }
      rethrow;
    }
  }

  /// Kimlige gore tek kategori getirir, yoksa null dondurur.
  Future<Category?> getCategoryById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Category.fromMap(rows.first);
  }

  /// Tum kategorileri ada gore sirali getirir.
  ///
  /// Gozlemlenebilir liste (watchTree) gerektiren katmanlar bu metodu
  /// cagirip sonucu [buildTree] ile agaca donusturmelidir; sqflite
  /// dogrudan akis (stream) saglamaz.
  Future<List<Category>> getAllCategories() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Kok kategorileri (ust kategorisi olmayanlar) getirir.
  Future<List<Category>> getRootCategories() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      where: 'parent_id IS NULL',
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Bir kategorinin dogrudan alt kategorilerini getirir.
  Future<List<Category>> getChildCategories(int parentId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      where: 'parent_id = ?',
      whereArgs: <Object?>[parentId],
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Tum kategori agacini kok dugumler listesi olarak dondurur.
  Future<List<CategoryNode>> getCategoryTree() async {
    final List<Category> flat = await getAllCategories();
    return buildTree(flat);
  }

  /// Duz kategori listesini hiyerarsik agaca donusturur.
  ///
  /// Yetim kalan (ust kaydi silinmis) kategoriler kok seviyesinde
  /// listelenir, veri kaybi yasanmaz.
  List<CategoryNode> buildTree(List<Category> flat) {
    final Map<int, CategoryNode> byId = <int, CategoryNode>{
      for (final Category c in flat) c.id: CategoryNode(c),
    };
    final List<CategoryNode> roots = <CategoryNode>[];
    for (final Category c in flat) {
      final CategoryNode node = byId[c.id]!;
      final int? parentId = c.parentId;
      final CategoryNode? parent =
          parentId == null ? null : byId[parentId];
      if (parent == null) {
        roots.add(node);
      } else {
        parent.children.add(node);
      }
    }
    void sortRecursively(List<CategoryNode> nodes) {
      nodes.sort(
        (CategoryNode a, CategoryNode b) =>
            a.category.name.toLowerCase().compareTo(
              b.category.name.toLowerCase(),
            ),
      );
      for (final CategoryNode n in nodes) {
        sortRecursively(n.children);
      }
    }

    sortRecursively(roots);
    return roots;
  }

  /// Bir kategorinin alt agacindaki tum kategori kimliklerini dondurur.
  ///
  /// [includeSelf] true ise (varsayilan) kategorinin kendisi de dahildir.
  /// Recursive CTE kullanir; derin hiyerarsilerde tek sorguda cozulur.
  Future<Set<int>> descendantIds(
    int categoryId, {
    bool includeSelf = true,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
WITH RECURSIVE subtree(id) AS (
  SELECT ? AS id
  UNION ALL
  SELECT c.id FROM categories c JOIN subtree s ON c.parent_id = s.id
)
SELECT id FROM subtree
''',
      <Object?>[categoryId],
    );
    final Set<int> ids = <int>{
      for (final Map<String, Object?> row in rows) row['id']! as int,
    };
    if (includeSelf) {
      return ids;
    }
    ids.remove(categoryId);
    return ids;
  }

  // -----------------------------------------------------------------
  // Urun CRUD
  // -----------------------------------------------------------------

  void _validateProductFields({
    required String name,
    required int quantity,
    String? imagePath,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Urun adi bos olamaz.');
    }
    if (quantity < 0) {
      throw ArgumentError('Adet negatif olamaz.');
    }
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      final String normalized = imagePath.replaceAll('\\', '/');
      if (p.isAbsolute(normalized) ||
          normalized.startsWith('/') ||
          normalized.contains('..')) {
        throw ArgumentError(
          'Gorsel yolu goreceli olmalidir (orn. images/ornek.jpg).',
        );
      }
    }
  }

  Future<void> _requireCategoryExists(
    Database db,
    int categoryId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      columns: <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>[categoryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Secilen kategori mevcut degil (id: $categoryId).');
    }
  }

  /// Yeni urun olusturur, satir kimligini dondurur.
  Future<int> insertProduct({
    required String name,
    String description = '',
    required int quantity,
    required int categoryId,
    String? imagePath,
  }) async {
    _validateProductFields(
      name: name,
      quantity: quantity,
      imagePath: imagePath,
    );
    final Database db = await database;
    await _requireCategoryExists(db, categoryId);
    final String now = DateTime.now().toIso8601String();
    return db.insert('products', <String, Object?>{
      'name': name.trim(),
      'description': description,
      'quantity': quantity,
      'category_id': categoryId,
      'image_path': _normalizeImagePath(imagePath),
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Urunu gunceller. Yalnizca verilen alanlar degistirilir.
  ///
  /// Gorseli kaldirmak icin [clearImage] true gecilmelidir; yeni gorsel
  /// verilirse [imagePath] kullanilir. [isFavorite] verilirse favori
  /// isareti 0/1 olarak yazilir.
  Future<void> updateProduct({
    required int id,
    String? name,
    String? description,
    int? quantity,
    int? categoryId,
    String? imagePath,
    bool clearImage = false,
    bool? isFavorite,
  }) async {
    final Database db = await database;
    final Product? existing = await getProductById(id);
    if (existing == null) {
      throw StateError('Urun bulunamadi (id: $id).');
    }
    final String nextName = name ?? existing.name;
    final int nextQuantity = quantity ?? existing.quantity;
    final String? nextImage =
        clearImage ? null : (imagePath ?? existing.imagePath);
    _validateProductFields(
      name: nextName,
      quantity: nextQuantity,
      imagePath: nextImage,
    );
    final int nextCategoryId = categoryId ?? existing.categoryId;
    await _requireCategoryExists(db, nextCategoryId);
    final Map<String, Object?> values = <String, Object?>{
      'name': nextName.trim(),
      'description': description ?? existing.description,
      'quantity': nextQuantity,
      'category_id': nextCategoryId,
      'image_path': _normalizeImagePath(nextImage),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (isFavorite != null) {
      values['is_favorite'] = isFavorite ? 1 : 0;
    }
    await db.update(
      'products',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Urunun favori isaretini tersine cevirir (0/1).
  ///
  /// Yeni favori durumunu dondurur (`true` favori). Kayit yoksa
  /// [StateError] firlatir.
  Future<bool> toggleFavorite(int id) async {
    final Database db = await database;
    final Product? existing = await getProductById(id);
    if (existing == null) {
      throw StateError('Urun bulunamadi (id: $id).');
    }
    final bool next = !existing.isFavorite;
    await db.update(
      'products',
      <String, Object?>{'is_favorite': next ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return next;
  }

  /// Urunu siler ve silinen kaydi dondurur.
  ///
  /// Cagiran katman, donen kaydın [Product.imagePath] alanindaki goreceli
  /// yolu tam yola cevirip yerel gorsel dosyasini diskten temizlemelidir.
  /// Kayit yoksa [StateError] firlatir.
  Future<Product> deleteProduct(int id) async {
    final Database db = await database;
    final Product? existing = await getProductById(id);
    if (existing == null) {
      throw StateError('Urun bulunamadi (id: $id).');
    }
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return existing;
  }

  /// Kimlige gore tek urun getirir, yoksa null dondurur.
  Future<Product?> getProductById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Product.fromMap(rows.first);
  }

  /// Bir kategorinin alt agacindaki (kendisi dahil) tum urunleri getirir.
  Future<List<Product>> productsByCategorySubtree(
    int categoryId, {
    ProductSortField sortBy = ProductSortField.name,
    bool ascending = true,
  }) async {
    return queryProducts(
      categoryId: categoryId,
      includeSubtree: true,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Urun adi ve aciklamasinda gercek zamanli arama yapar.
  ///
  /// Bos veya yalnizca bosluk iceren [query] tum kayitlari dondurur.
  /// [categoryId] verilirse sonuclar o kategorinin alt agaci ile
  /// sinirlandirilir.
  Future<List<Product>> search(
    String query, {
    int? categoryId,
    ProductSortField sortBy = ProductSortField.name,
    bool ascending = true,
  }) async {
    return queryProducts(
      search: query,
      categoryId: categoryId,
      includeSubtree: true,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Tum urunleri istenen siralama ile getirir.
  Future<List<Product>> sortedList({
    ProductSortField sortBy = ProductSortField.name,
    bool ascending = true,
  }) async {
    return queryProducts(sortBy: sortBy, ascending: ascending);
  }

  /// Esnek urun sorgusu: arama + kategori filtresi + siralama.
  ///
  /// [includeSubtree] true ise [categoryId] alt agaci (recursive CTE)
  /// ile eslestirilir; false ise yalnizca dogrudan uyeler gelir.
  Future<List<Product>> queryProducts({
    String? search,
    int? categoryId,
    bool includeSubtree = true,
    ProductSortField sortBy = ProductSortField.name,
    bool ascending = true,
  }) async {
    final Database db = await database;
    final List<String> where = <String>[];
    final List<Object?> args = <Object?>[];

    final String? keyword = search?.trim();
    if (keyword != null && keyword.isNotEmpty) {
      final String pattern = '%${_escapeLike(keyword)}%';
      where.add(
        '(p.name LIKE ? ESCAPE \'\\\' OR p.description LIKE ? ESCAPE \'\\\')',
      );
      args.add(pattern);
      args.add(pattern);
    }

    if (categoryId != null) {
      if (includeSubtree) {
        where.add('''
p.category_id IN (
  WITH RECURSIVE subtree(id) AS (
    SELECT ? AS id
    UNION ALL
    SELECT c.id FROM categories c JOIN subtree s ON c.parent_id = s.id
  )
  SELECT id FROM subtree
)''');
        args.add(categoryId);
      } else {
        where.add('p.category_id = ?');
        args.add(categoryId);
      }
    }

    final String orderColumn = _sortColumn(sortBy);
    final String direction = ascending ? 'ASC' : 'DESC';
    final String sql = '''
SELECT p.id, p.name, p.description, p.quantity, p.category_id,
       p.image_path, p.is_favorite, p.created_at, p.updated_at
FROM products p
${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
ORDER BY $orderColumn $direction, p.id ASC
''';
    final List<Map<String, Object?>> rows = await db.rawQuery(sql, args);
    return rows.map(Product.fromMap).toList();
  }

  /// Bir kategoriye dogrudan bagli urun sayisini dondurur.
  Future<int> countProductsInCategory(
    int categoryId, {
    bool includeSubtree = true,
  }) async {
    final Database db = await database;
    if (!includeSubtree) {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM products WHERE category_id = ?',
        <Object?>[categoryId],
      );
      return (rows.first['n']! as int);
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
SELECT COUNT(*) AS n FROM products p
WHERE p.category_id IN (
  WITH RECURSIVE subtree(id) AS (
    SELECT ? AS id
    UNION ALL
    SELECT c.id FROM categories c JOIN subtree s ON c.parent_id = s.id
  )
  SELECT id FROM subtree
)''',
      <Object?>[categoryId],
    );
    return (rows.first['n']! as int);
  }

  /// Dogrudan urun sayilarini tek sorguda dondurur (`category_id -> adet`).
  ///
  /// Kategori sekmesindeki N+1 sayim yerine kullanilir: tek `GROUP BY`
  /// sorgusu + bellek ici alt-agac toplami, kategori sayisindan bagimsiz
  /// sabit sorgu maliyeti saglar.
  Future<Map<int, int>> countDirectProductsPerCategory() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT category_id AS id, COUNT(*) AS n FROM products '
      'GROUP BY category_id',
    );
    return <int, int>{
      for (final Map<String, Object?> row in rows)
        (row['id']! as int): (row['n']! as int),
    };
  }

  String _sortColumn(ProductSortField sortBy) {
    switch (sortBy) {
      case ProductSortField.name:
        return 'p.name COLLATE NOCASE';
      case ProductSortField.quantity:
        return 'p.quantity';
      case ProductSortField.createdAt:
        return 'p.created_at';
      case ProductSortField.updatedAt:
        return 'p.updated_at';
    }
  }

  String? _normalizeImagePath(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll('\\', '/');
  }

  /// LIKE joker karakterlerini (`%`, `_`, `\`) etkisizlestirir.
  String _escapeLike(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
