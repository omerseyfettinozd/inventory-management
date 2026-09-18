// lib/screens/inventory_tab.dart
//
// Envanter ana ekrani (Inventory Tab).
//
// Icerik:
// - Gercek zamanli arama alani (onChanged -> InventoryProvider.setSearch).
// - Favoriler bolumu: baslik + bagimsiz siralama (favSortField/favSortAsc)
//   + favori urunler (bosken bilgi metni).
// - Tum urunler bolumu: baslik + ana siralama (sortField/sortAsc) + sonuc
//   sayisi + tum urun listesi.
// - Urun kartinda yildizla favori isareti, duzenleme ve onayli silme.
// - Bos durum (EmptyState).
// - Duzenleme: ProductFormScreen(product: ...).
// - Onayli silme: "Bu ürünü envanterden silmek istediğinize emin misiniz?"
//   metniyle [showConfirmDeleteDialog], onayda provider.deleteProduct.
//
// Kurallar (kesin):
// - SADECE karanlik mod ([AppTheme.darkTheme] disinda tema kullanilmaz).
// - Renkler yalnizca [AppColors] uzerinden.
// - Emoji yasak: bu dosyada hicbir stringde emoji yoktur.
// - Ikonlar: yalnizca Flutter Material Icons (ince hatli kullanim).
// - Rakamlar: FontFeature.tabularFigures() ile tek aralikli hizalama.
//
// Gercek API sozlesmesi (InventoryProvider):
//     String get searchQuery;            void setSearch(String value);
//     ProductSortField get sortField;    bool get sortAsc;
//     void setSort(ProductSortField field, [bool ascending]);
//     ProductSortField get favSortField; bool get favSortAsc;
//     void setFavSort(ProductSortField field, [bool ascending]);
//     List<Product> get filteredProducts;
//     List<Product> get favoriteProducts;
//     Future<bool?> toggleFavorite(int id); // yeni durum, hatada null
//     bool get isLoading;
//     Future<bool> deleteProduct(int id); // kayit + yerel gorsel dosyasi
// - ProductFormScreen({Key? key, Product? product})

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:inventory_management/db/app_database.dart';
import 'package:inventory_management/providers/inventory_provider.dart';
import 'package:inventory_management/screens/product_form_screen.dart';
import 'package:inventory_management/theme/app_theme.dart';
import 'package:inventory_management/widgets/product_thumbnail.dart';

/// Rakam iceren metinler icin tabular (tek aralikli) stil.
///
/// Ornek: `Text('Adet: 3', style: tabular(context, ...))`
TextStyle _tabular(BuildContext context, TextStyle? base) {
  final TextStyle resolved =
      base ?? Theme.of(context).textTheme.bodyMedium!;
  return resolved.copyWith(
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// gg.AA.yyyy biciminde tarih metni (orn. 17.09.2026).
String _formatDate(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

// ---------------------------------------------------------------------------
// InventoryTab
// ---------------------------------------------------------------------------

/// Envanter sekmesi: arama + favoriler bolumu + tum urunler listesi.
class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  TextEditingController? _searchController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchController ??= TextEditingController(
      text: context.read<InventoryProvider>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController?.dispose();
    super.dispose();
  }

  Future<void> _openAddForm() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ProductFormScreen(),
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    // Form dogrudan AppDatabase yazar; provider listesini tazele,
    // yoksa yeni urun gorunmez.
    await context.read<InventoryProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final InventoryProvider provider = context.watch<InventoryProvider>();
    final List<Product> favorites = provider.favoriteProducts;
    final List<Product> all = provider.filteredProducts;

    Widget productItem(BuildContext context, int index, List<Product> source) {
      final Product product = source[index];
      return _ProductCard(
        key: ValueKey<int>(product.id),
        product: product,
        categoryName: _categoryNameById(
          provider.categoryTree,
          product.categoryId,
        ),
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _SearchField(controller: _searchController!),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _SectionHeader(
              title: 'Favoriler',
              field: provider.favSortField,
              ascending: provider.favSortAsc,
              resultCount: favorites.length,
              onChanged: (ProductSortField field, bool ascending) {
                provider.setFavSort(field, ascending);
              },
            ),
          ),
        ),
        if (provider.isLoading && all.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (all.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(onAdd: _openAddForm),
          )
        else ...<Widget>[
          if (favorites.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Henüz favori ürün yok. '
                  'Karttaki yıldıza dokunarak ekleyin.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              sliver: SliverList.builder(
                itemCount: favorites.length,
                itemBuilder: (BuildContext context, int index) =>
                    productItem(context, index, favorites),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: _SectionHeader(
                title: 'Tüm ürünler',
                field: provider.sortField,
                ascending: provider.sortAsc,
                resultCount: all.length,
                onChanged: (ProductSortField field, bool ascending) {
                  provider.setSort(field, ascending);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
            sliver: SliverList.builder(
              itemCount: all.length,
              itemBuilder: (BuildContext context, int index) =>
                  productItem(context, index, all),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kategori agacinda [id] karsiligi kategori adini bulur.
String? _categoryNameById(List<CategoryNode> tree, int id) {
  for (final CategoryNode node in tree) {
    if (node.category.id == id) {
      return node.category.name;
    }
    final String? nested = _categoryNameById(node.children, id);
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Arama alani
// ---------------------------------------------------------------------------

/// Gercek zamanli arama: her tusta provider.setSearch cagrilir.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: (String value) {
        context.read<InventoryProvider>().setSearch(value);
      },
      decoration: InputDecoration(
        hintText: 'Ürün ara...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (BuildContext context, TextEditingValue value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: 'Temizle',
              icon: const Icon(Icons.clear),
              onPressed: () {
                controller.clear();
                context.read<InventoryProvider>().setSearch('');
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bolum basligi: baslik metni + bagimsiz siralama satiri
// ---------------------------------------------------------------------------

/// Liste bolumu basligi (orn. "Favoriler" / "Tüm ürünler").
///
/// Altinda [_SortRow] aynen yeniden kullanilir; [field]/[ascending]
/// hangi siralama durumuna bagliysa (favori veya ana) cagiran taraf verir.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.field,
    required this.ascending,
    required this.resultCount,
    required this.onChanged,
  });

  final String title;
  final ProductSortField field;
  final bool ascending;
  final int resultCount;
  final void Function(ProductSortField field, bool ascending) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        _SortRow(
          field: field,
          ascending: ascending,
          resultCount: resultCount,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Siralama satiri: SortMenu + sonuc sayisi
// ---------------------------------------------------------------------------

/// Siralama alani secimi (Ad / Stok / Tarih) + yon + sonuc sayisi.
class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.field,
    required this.ascending,
    required this.resultCount,
    required this.onChanged,
  });

  final ProductSortField field;
  final bool ascending;
  final int resultCount;
  final void Function(ProductSortField field, bool ascending) onChanged;

  String _fieldLabel(ProductSortField value) {
    switch (value) {
      case ProductSortField.name:
        return 'Ad';
      case ProductSortField.quantity:
        return 'Stok';
      case ProductSortField.createdAt:
        return 'Tarih';
      case ProductSortField.updatedAt:
        return 'Güncelleme';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        PopupMenuButton<ProductSortField>(
          tooltip: 'Sıralama',
          onSelected: (ProductSortField value) {
            onChanged(value, ascending);
          },
          itemBuilder: (BuildContext context) {
            return <PopupMenuEntry<ProductSortField>>[
              for (final ProductSortField option in <ProductSortField>[
                ProductSortField.name,
                ProductSortField.quantity,
                ProductSortField.createdAt,
              ])
                PopupMenuItem<ProductSortField>(
                  value: option,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        option == field
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(_fieldLabel(option)),
                    ],
                  ),
                ),
            ];
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 8),
                Text(
                  _fieldLabel(field),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: ascending ? 'Artan sıralama' : 'Azalan sıralama',
          icon: Icon(
            ascending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          onPressed: () => onChanged(field, !ascending),
        ),
        const Spacer(),
        Text(
          '$resultCount sonuç',
          style: _tabular(
            context,
            Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Urun karti
// ---------------------------------------------------------------------------

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.categoryName,
  });

  final Product product;
  final String? categoryName;

  Future<void> _openEditForm(BuildContext context) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
    if (!context.mounted || saved != true) {
      return;
    }
    await context.read<InventoryProvider>().loadAll();
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final InventoryProvider provider = context.read<InventoryProvider>();
    final bool? next = await provider.toggleFavorite(product.id);
    if (!context.mounted) {
      return;
    }
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.lastError ?? 'Favori güncellenemedi.'),
        ),
      );
    }
  }

  Future<void> _askDelete(BuildContext context) async {
    final bool confirmed = await showConfirmDeleteDialog(
      context,
      productName: product.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final bool ok =
          await context.read<InventoryProvider>().deleteProduct(product.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Ürün silindi.' : 'Silme başarısız.'),
        ),
      );
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme başarısız: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProductThumbnail(relativePath: product.imagePath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (product.description.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      product.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'Adet: ${product.quantity}',
                        style: _tabular(
                          context,
                          textTheme.bodyMedium?.copyWith(
                            color: AppColors.boneWhiteDim,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(product.createdAt),
                        style: _tabular(context, textTheme.bodySmall),
                      ),
                    ],
                  ),
                  if (categoryName != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      categoryName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: product.isFavorite
                      ? 'Favorilerden çıkar'
                      : 'Favorilere ekle',
                  icon: Icon(
                    product.isFavorite ? Icons.star : Icons.star_outlined,
                    size: 20,
                    color: product.isFavorite
                        ? AppColors.warning
                        : AppColors.secondaryText,
                  ),
                  onPressed: () => _toggleFavorite(context),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openEditForm(context),
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _askDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bos durum
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'Urun bulunamadi',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni urun ekleyin',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ürün ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onayli silme diyalogu
// ---------------------------------------------------------------------------

/// Silme onay diyalogunu acar. Onaylandiysa true doner.
///
/// [productName] baslikta gosterilir; onay metni sartname ile birebir aynidir.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  String? productName,
}) async {
  final String title = (productName == null || productName.trim().isEmpty)
      ? 'Ürünü sil'
      : 'Ürünü sil: ${productName.trim()}';
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: const Text(
          'Bu ürünü envanterden silmek istediğinize emin misiniz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
