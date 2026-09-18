import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Ürün görsellerinin dosya sistemi üzerindeki yaşam döngüsünü yönetir.
///
/// Mimari kararlar:
/// - Görseller SQLite içine BLOB olarak yazılmaz. Yalnızca işletim
///   sisteminin güvenli uygulama veri klasörü
///   (`getApplicationSupportDirectory()`) altındaki `images/` dizininde
///   saklanır.
/// - Veritabanındaki `products.image_path` kolonunda göreceli yol tutulur:
///   `images/<uuid>.<uzanti>`. Mutlak yol tutulmaz; çünkü mutlak yol
///   platforma ve kuruluma göre değişir.
/// - Bu sınıf yalnızca dosya işlemleri yapar. Kamera/galeri seçimi
///   (image_picker vb.) UI katmanının sorumluluğundadır ve burada yer almaz.
class ImageStore {
  ImageStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Tekil görsel dosyası için üst sınır: 10 MB.
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// İzin verilen dosya uzantıları (küçük harf, noktasız).
  static const Set<String> allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Dizin adı; hem fiziksel klasör adı hem göreceli yol öneki olarak kullanılır.
  static const String imagesDirName = 'images';

  final Uuid _uuid;

  Directory? _imagesDir;

  /// `init()` çağrıldı mı?
  bool get isInitialized => _imagesDir != null;

  /// Görsellerin saklandığı mutlak dizin. [init] sonrası kullanılabilir.
  Directory get imagesDir {
    final dir = _imagesDir;
    if (dir == null) {
      throw StateError(
        'ImageStore kullanılmadan önce init() çağrılmalıdır.',
      );
    }
    return dir;
  }

  /// `<appSupport>/images` dizinini oluşturur (yoksa) ve kullanıma hazırlar.
  /// Uygulama açılışında bir kez çağrılmalıdır. İdempotenttir.
  Future<Directory> init() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, imagesDirName));
    await dir.create(recursive: true);
    _imagesDir = dir;
    return dir;
  }

  /// Testlerde veya özel kurulumlarda dizini doğrudan enjekte eder.
  /// Üretim kodunda bunun yerine [init] kullanılmalıdır.
  void initWithDirectory(Directory directory) {
    _imagesDir = directory;
  }

  /// Kaynak görseli uygulamaya kopyalar ve göreceli yolunu döndürür.
  ///
  /// Kontroller:
  /// - [source] mevcut bir dosya olmalıdır.
  /// - Dosya boyutu [maxFileSizeBytes] değerini aşmamalıdır.
  /// - Uzantı [allowedExtensions] içinde olmalıdır.
  ///
  /// Başarılı durumda `images/<uuid>.<uzanti>` biçiminde göreceli yol döner.
  /// Hata durumunda [ImageStoreException] fırlatır.
  Future<String> saveImage(File source) async {
    final dir = imagesDir;

    if (!await source.exists()) {
      throw const ImageStoreException('Kaynak görsel dosyası bulunamadı.');
    }

    final size = await source.length();
    if (size > maxFileSizeBytes) {
      throw const ImageStoreException(
        'Görsel boyutu çok büyük (en fazla ${maxFileSizeBytes ~/ (1024 * 1024)} MB).',
      );
    }
    if (size == 0) {
      throw const ImageStoreException('Görsel dosyası boş olamaz.');
    }

    final extension = _normalizedExtension(source.path);
    if (!allowedExtensions.contains(extension)) {
      throw ImageStoreException(
        'Desteklenmeyen görsel biçimi: .$extension '
        '(desteklenenler: ${allowedExtensions.join(', ')}).',
      );
    }

    final fileName = '${_uuid.v4()}.$extension';
    final destination = File(p.join(dir.path, fileName));
    await source.copy(destination.path);

    return '$imagesDirName/$fileName';
  }

  /// Göreceli yolu mutlak [File] karşılığına çevirir.
  ///
  /// [relative] null veya boş ise null döner. Dosyanın fiziksel olarak
  /// var olup olmadığı kontrol edilmez; çağıran taraf `await file.exists()`
  /// ile kontrol edebilir. Yol dizinden kaçışı (path traversal) engellenir:
  /// çözümlenen yol `images/` dışına taşarsa null döner.
  File? resolve(String? relative) {
    if (relative == null || relative.trim().isEmpty) {
      return null;
    }
    final dir = imagesDir;
    final sanitized = relative.trim().replaceAll('\\', '/');
    final fileName = p.basename(sanitized);
    if (fileName.isEmpty || fileName == '.' || fileName == '..') {
      return null;
    }
    // Uzantı güvenliği: yalnızca izinli uzantılar çözümlenir.
    if (!allowedExtensions.contains(_normalizedExtension(fileName))) {
      return null;
    }
    final absolute = p.normalize(p.join(dir.path, fileName));
    if (!p.isWithin(dir.path, absolute) && absolute != p.join(dir.path, fileName)) {
      return null;
    }
    return File(absolute);
  }

  /// Göreceli yola karşılık gelen dosyayı siler.
  ///
  /// [relative] null/boş ise veya dosya zaten yoksa sessizce döner
  /// (hata fırlatmaz). Uzanti izin listesinde olmasa bile dizin dışına
  /// taşmayan dosya silinir; yoksa ürün silme yetim dosya bırakırdı.
  /// Silme sırasındaki dosya sistemi hataları da yutulur; çünkü silme
  /// genellikle kayıt silme akışının tamamlayıcısıdır ve ana işlemi
  /// engellememelidir.
  Future<void> deleteByRelative(String? relative) async {
    if (relative == null || relative.trim().isEmpty) {
      return;
    }
    final File? file = _resolveForDelete(relative);
    if (file == null) {
      return;
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Bilinçli olarak sessiz geçilir (bkz. dokümantasyon).
    }
  }

  /// Silme amaçlı çözümleme: [resolve] ile aynı dizin-dışı korumasını
  /// uygular ancak uzantı filtresini uygulamaz.
  File? _resolveForDelete(String relative) {
    final dir = imagesDir;
    final sanitized = relative.trim().replaceAll('\\', '/');
    final fileName = p.basename(sanitized);
    if (fileName.isEmpty || fileName == '.' || fileName == '..') {
      return null;
    }
    final absolute = p.normalize(p.join(dir.path, fileName));
    if (!p.isWithin(dir.path, absolute) &&
        absolute != p.join(dir.path, fileName)) {
      return null;
    }
    return File(absolute);
  }

  /// Mevcut görseli yenisiyle değiştirir.
  ///
  /// Önce yeni dosya kaydedilir, kayıt başarılı olursa eski dosya silinir.
  /// Böylece kopyalama başarısız olduğunda eski görsel korunmuş olur.
  /// Yeni göreceli yolu döndürür.
  Future<String> replace(String? oldRelative, File newSource) async {
    final newRelative = await saveImage(newSource);
    if (oldRelative != null &&
        oldRelative.trim().isNotEmpty &&
        oldRelative != newRelative) {
      await deleteByRelative(oldRelative);
    }
    return newRelative;
  }

  /// Dizinde duran ancak [knownRelative] kümesinde kaydı bulunmayan
  /// yetim dosyaları listeler.
  ///
  /// [knownRelative] veritabanındaki `image_path` değerler kümesidir.
  /// Karşılaştırma dosya adına göre yapılır; hem `images/x` hem yalın
  /// `x` biçimindeki girdiler tolere edilir.
  Future<List<File>> scanOrphans(Set<String> knownRelative) async {
    final dir = imagesDir;
    if (!await dir.exists()) {
      return <File>[];
    }
    final knownNames = knownRelative
        .map((e) => p.basename(e.trim().replaceAll('\\', '/')).toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final orphans = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path).toLowerCase();
      if (!knownNames.contains(name)) {
        orphans.add(entity);
      }
    }
    return orphans;
  }

  /// Yetim dosyaları siler ve silinen dosya sayısını döndürür.
  Future<int> deleteOrphans(Set<String> knownRelative) async {
    final orphans = await scanOrphans(knownRelative);
    var deleted = 0;
    for (final file in orphans) {
      try {
        if (await file.exists()) {
          await file.delete();
          deleted++;
        }
      } on FileSystemException {
        continue;
      }
    }
    return deleted;
  }

  String _normalizedExtension(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }
}

/// Görsel kaydetme/doğrulama hataları için istisna türü.
/// Mesajlar doğrudan UI da gösterilebilir (Türkçe, emoji içermez).
class ImageStoreException implements Exception {
  const ImageStoreException(this.message);

  final String message;

  @override
  String toString() => 'ImageStoreException: $message';
}
