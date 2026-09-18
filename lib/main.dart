import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/inventory_provider.dart';
import 'screens/home_screen.dart';
import 'services/image_store.dart';
import 'theme/app_theme.dart';

/// Uygulama girişi.
///
/// Başlatma sırası (tüm platformlarda aynı):
/// 1. Widget bağını kur.
/// 2. Yalnızca masaüstünde (Windows/Linux) `sqfliteFfiInit()` çağır.
/// 3. [ImageStore] dizinini hazırla ve [InventoryProvider] içine enjekte et
///    (böylece görselli ürün ekleme/güncelleme/silme dosya temizliğiyle çalışır).
/// 4. Yalnızca karanlık modla (`ThemeMode.dark` sabit) çalıştır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }

  final ImageStore imageStore = ImageStore();
  try {
    await imageStore.init();
  } catch (_) {
    // Dizin hazırlığı başarısız olursa uygulama yine açılır;
    // ilgili ekranlar kendi ImageStore örneklerini tembelce başlatır
    // ve hatayı Türkçe mesajla gösterir.
  }

  runApp(InventoryApp(imageStore: imageStore));
}

/// Kök widget. Açık mod tanımı yoktur.
class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key, required this.imageStore});

  final ImageStore imageStore;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InventoryProvider>(
      create: (_) => InventoryProvider(images: imageStore)..loadAll(),
      child: MaterialApp(
        title: 'Inventory Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
