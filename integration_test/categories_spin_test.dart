import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:inventory_management/db/app_database.dart';
import 'package:inventory_management/main.dart' as app;

// Linux masaustu yeniden uretimi: Kategoriler sekmesi takilmadan acilmali.
//
// Calistirma (veri izolasyonlu):
//   XDG_DATA_HOME=/tmp/invtest flutter test -d linux integration_test/categories_spin_test.dart
//
// Test, destek dizininin /tmp/invtest altinda oldugunu dogrulamadan
// veritabanina DOKUNMAZ; koruma tutmazsa hizli basarisiz olur.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Test govdesi app.main()'den ONCE veritabanina dokunur; masaustunde
  // FFI baslatilmadan global factory okunamaz, once burada kurulur.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'Kategoriler sekmesi Linux masaustunde takilmadan acilir',
    (WidgetTester tester) async {
      final support = await getApplicationSupportDirectory();
      // ignore: avoid_print
      print('ITEST SUPPORT_DIR=${support.path}');
      if (!support.path.startsWith('/tmp/invtest')) {
        fail(
          'Veri izolasyonu yok (SUPPORT_DIR=${support.path}); '
          'XDG_DATA_HOME=/tmp/invtest ile calistirin.',
        );
      }

      await _seed(tester);
      // Soguk baslatma sadakati: uygulama acilisindaki eszamanli acilis
      // yarisini (provider.loadAll + _reload) gercekten test etmek icin
      // tohum baglantisi kapatilir.
      await AppDatabase().close();
      // ignore: avoid_print
      print('ITEST tohum baglantisi kapatildi, uygulama baslatiliyor');

      app.main();
      final bool opened =
          await _waitForNoSpinner(tester, const Duration(seconds: 60));
      // ignore: avoid_print
      print('ITEST uygulama acildi (spinner bitti: $opened)');
      expect(opened, isTrue, reason: 'Acilis yuklemesi 60 snde bitmedi.');

      await tester.tap(find.text('Kategoriler').first);
      final bool settled =
          await _waitForNoSpinner(tester, const Duration(seconds: 30));
      final bool retry =
          find.text('Tekrar Dene').evaluate().isNotEmpty;
      // ignore: avoid_print
      print('ITEST kategori ekrani: spinner bitti=$settled retry=$retry');
      expect(settled, isTrue,
          reason: 'Kategoriler ekrani 30 snde yerlesmedi (donen cark).');
      expect(find.text('Tekrar Dene'), findsNothing);
      expect(find.text('El Aletleri'), findsOneWidget);

      // Alt kategori + resimli urun yolu da calismali: genislet, urunu gor.
      await tester.tap(find.text('El Aletleri').first);
      final bool expanded =
          await _waitForNoSpinner(tester, const Duration(seconds: 30));
      // ignore: avoid_print
      print('ITEST genisletme sonrasi spinner bitti=$expanded');
      expect(expanded, isTrue);
      expect(find.text('Cekic'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Kullanicidakine benzer tohum veri: alt kategori, resimli urun, favori.
///
/// Eklemeli calisir (var olan atlanir), boylece tekrar kosulabilir.
Future<void> _seed(WidgetTester tester) async {
  final AppDatabase db = AppDatabase();
  final List<Category> existing = await db.getAllCategories();
  // ignore: avoid_print
  print('ITEST mevcut kategori sayisi: ${existing.length}');

  int idOf(String name) {
    return existing
        .firstWhere((Category c) => c.name == name)
        .id;
  }

  int elAletleri;
  if (existing.any((Category c) => c.name == 'El Aletleri')) {
    elAletleri = idOf('El Aletleri');
  } else {
    elAletleri = await db.insertCategory(name: 'El Aletleri');
    // ignore: avoid_print
    print('ITEST tohum kategori eklendi: El Aletleri');
  }
  if (existing.every((Category c) => c.name != 'Elektrik')) {
    await db.insertCategory(name: 'Elektrik');
    // ignore: avoid_print
    print('ITEST tohum kategori eklendi: Elektrik');
  }
  if (existing.every((Category c) => c.name != 'Tornavidalar')) {
    await db.insertCategory(name: 'Tornavidalar', parentId: elAletleri);
    // ignore: avoid_print
    print('ITEST tohum alt kategori eklendi: Tornavidalar');
  }

  final List<Product> products = await db.queryProducts();
  if (products.every((Product pr) => pr.name != 'Cekic')) {
    String? imagePath;
    try {
      final Directory support = await getApplicationSupportDirectory();
      final Directory imagesDir =
          Directory(p.join(support.path, 'images'));
      await imagesDir.create(recursive: true);
      final File dest = File(p.join(imagesDir.path, 'seed.png'));
      if (!await dest.exists()) {
        // flutter test calisma dizini paket kokudur.
        final File src = File('assets/icon/app_icon.png');
        if (await src.exists()) {
          await src.copy(dest.path);
        }
      }
      if (await dest.exists()) {
        imagePath = 'images/seed.png';
      }
    } catch (e) {
      // ignore: avoid_print
      print('ITEST tohum gorsel kopyalanamadi, gorselsiz devam: $e');
    }
    final int cekic = await db.insertProduct(
      name: 'Cekic',
      description: 'Tohum urun',
      quantity: 3,
      categoryId: elAletleri,
      imagePath: imagePath,
    );
    await db.updateProduct(id: cekic, isFavorite: true);
    // ignore: avoid_print
    print('ITEST tohum urun eklendi: Cekic (gorsel: $imagePath, favori)');
  }
}

/// Donen cark kalmayana (veya [limit] dolana) kadar pompa yapar.
///
/// Cark bittiyse true doner; sure dolup cark suruyorsa false.
Future<bool> _waitForNoSpinner(WidgetTester tester, Duration limit) async {
  final DateTime end = DateTime.now().add(limit);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // Tek karelik animasyon artigi icin bir tur daha bosalt.
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return true;
      }
    }
  }
  return find.byType(CircularProgressIndicator).evaluate().isEmpty;
}
