import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import 'categories_tab.dart';
import 'inventory_tab.dart';
import 'product_form_screen.dart';

/// Ana iskelet: iki sekme (Envanter / Kategoriler).
///
/// - Dar ekranda alt çubuk, geniş ekranda (masaüstü) sol [NavigationRail].
/// - Başlıkta toplam ürün rozeti (tek aralıklı rakam).
/// - FAB yalnızca Envanter sekmesinde görünür (ürün ekleme);
///   Kategoriler sekmesinin kendi "Kök Kategori Ekle" eylemi vardır.
/// - Masaüstü kısayolu: `Ctrl+N` ürün formu açar.
/// - Yalnızca karanlık mod; emoji kullanılmaz.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  Future<void> _openProductForm() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ProductFormScreen(),
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    await context.read<InventoryProvider>().loadAll();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ürün kaydedildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = context.watch<InventoryProvider>().products.length;
    final bool wide = MediaQuery.widthOf(context) >= 800;

    final Widget body = IndexedStack(
      index: _index,
      children: const <Widget>[
        InventoryTab(),
        CategoriesTab(),
      ],
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _openProductForm,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Envanter Yönetimi'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.card,
                    ),
                    child: Text(
                      'Toplam $total',
                      style: const TextStyle(
                        color: AppColors.boneWhiteDim,
                        fontSize: 12,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      backgroundColor: AppColors.background,
                      unselectedIconTheme: const IconThemeData(
                        color: AppColors.secondaryText,
                      ),
                      selectedIconTheme: const IconThemeData(
                        color: AppColors.boneWhite,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        color: AppColors.secondaryText,
                      ),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppColors.boneWhite,
                      ),
                      destinations: const <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(AppIcons.products),
                          label: Text('Envanter'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(AppIcons.categories),
                          label: Text('Kategoriler'),
                        ),
                      ],
                      selectedIndex: _index,
                      onDestinationSelected: (int i) =>
                          setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : BottomNavigationBar(
                  backgroundColor: AppColors.background,
                  selectedItemColor: AppColors.boneWhite,
                  unselectedItemColor: AppColors.secondaryText,
                  currentIndex: _index,
                  onTap: (int i) => setState(() => _index = i),
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(AppIcons.products),
                      label: 'Envanter',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(AppIcons.categories),
                      label: 'Kategoriler',
                    ),
                  ],
                ),
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
                  onPressed: _openProductForm,
                  icon: const Icon(AppIcons.add),
                  label: const Text('Ürün Ekle'),
                )
              : null,
        ),
      ),
    );
  }
}
