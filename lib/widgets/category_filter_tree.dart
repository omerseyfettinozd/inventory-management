import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';

/// Envanter ekraninda kategori / alt kategori filtreleme agaci.
///
/// - En ustte "Tumu" secim cipi bulunur; seciliyken filtre kapalidir
///   ([selectedId] null).
/// - Kok kategoriler [ExpansionTile] olarak listelenir, alt kategoriler
///   ic ice ayni bilesenle cizilir.
/// - Secili kategori vurgulanir; secili kategorinin kokten baslayan
///   breadcrumb yolu ustte gosterilir.
/// - [productCounts] verilirse her kategori adinin yaninda urun sayisi
///   tek aralikli rakamla gosterilir.
///
/// Kullanim:
/// ```dart
/// CategoryFilterTree(
///   categories: categories,
///   selectedId: filterCategoryId,
///   onSelect: (id) => provider.setCategoryFilter(id),
///   productCounts: counts,
/// )
/// ```
///
/// Not: Kaydirilabilir bir [ListView] dondurur (`shrinkWrap: true`).
/// Dar alanlarda (cekmece, alt sayfa) dogrudan, genis alanlarda
/// `Expanded` veya sabit yukseklikli kutu icinde kullanilir.
class CategoryFilterTree extends StatelessWidget {
  const CategoryFilterTree({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.productCounts,
  });

  /// Tum kategoriler (duz liste). Agac bu listeden turetilir.
  final List<Category> categories;

  /// Secili kategori kimligi. Null ise "Tumu" secilidir.
  final int? selectedId;

  /// Secim degisikligi geri cagrisi. "Tumu" secilirse null iletilir.
  final ValueChanged<int?> onSelect;

  /// Kategori kimligine gore urun sayilari (opsiyonel).
  final Map<int, int>? productCounts;

  @override
  Widget build(BuildContext context) {
    final Map<int?, List<Category>> byParent = <int?, List<Category>>{};
    for (final Category c in categories) {
      byParent.putIfAbsent(c.parentId, () => <Category>[]).add(c);
    }
    for (final List<Category> group in byParent.values) {
      group.sort(
        (Category a, Category b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    final String breadcrumb = _breadcrumb(categories, selectedId);
    final Set<int> expandedIds = _ancestorIds(categories, selectedId);

    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilterChip(
              label: const Text('Tumu'),
              selected: selectedId == null,
              onSelected: (bool value) {
                if (value) {
                  onSelect(null);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selectedId == null ? 'Konum: Tumu' : 'Konum: $breadcrumb',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const Divider(height: 16),
        if (byParent[null]?.isEmpty ?? true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Henuz kategori yok. Urun formundaki "Kategori Ekle" '
              'butonu ile olusturun.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
          )
        else
          ...byParent[null]!.map(
            (Category root) => _NodeTile(
              category: root,
              depth: 0,
              selectedId: selectedId,
              onSelect: onSelect,
              byParent: byParent,
              productCounts: productCounts,
              expandedIds: expandedIds,
            ),
          ),
      ],
    );
  }
}

/// Agactaki tek kategori dugumu (yaprak veya dal).
class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.category,
    required this.depth,
    required this.selectedId,
    required this.onSelect,
    required this.byParent,
    required this.productCounts,
    required this.expandedIds,
  });

  final Category category;
  final int depth;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final Map<int?, List<Category>> byParent;
  final Map<int, int>? productCounts;
  final Set<int> expandedIds;

  @override
  Widget build(BuildContext context) {
    final List<Category> children = byParent[category.id] ?? <Category>[];
    final bool isSelected = selectedId == category.id;
    final int? count = productCounts?[category.id];

    final Widget title = Text(
      count == null ? category.name : '${category.name} ($count)',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isSelected ? AppColors.boneWhite : AppColors.boneWhiteDim,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );

    final IconData leadingIcon = children.isEmpty
        ? AppIcons.folder
        : (expandedIds.contains(category.id)
              ? AppIcons.folderOpen
              : AppIcons.folder);

    if (children.isEmpty) {
      return ListTile(
        dense: true,
        leading: Icon(
          leadingIcon,
          size: AppIcons.defaultSize,
          color: isSelected
              ? AppColors.boneWhite
              : AppColors.secondaryText,
        ),
        title: title,
        selected: isSelected,
        selectedTileColor: AppColors.surfaceVariant,
        selectedColor: AppColors.boneWhite,
        contentPadding: EdgeInsets.only(
          left: 16.0 + depth * 16.0,
          right: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
        onTap: () => onSelect(category.id),
      );
    }

    return ExpansionTile(
      key: PageStorageKey<int>(category.id),
      initiallyExpanded: expandedIds.contains(category.id),
      dense: true,
      leading: Icon(
        leadingIcon,
        size: AppIcons.defaultSize,
        color: isSelected
            ? AppColors.boneWhite
            : AppColors.secondaryText,
      ),
      title: GestureDetector(
        onTap: () => onSelect(category.id),
        child: title,
      ),
      tilePadding: EdgeInsets.only(
        left: 16.0 + depth * 8.0,
        right: 8,
      ),
      childrenPadding: EdgeInsets.zero,
      collapsedIconColor: AppColors.secondaryText,
      iconColor: AppColors.boneWhiteDim,
      backgroundColor: isSelected
          ? AppColors.surfaceVariant.withValues(alpha: 0.4)
          : Colors.transparent,
      children: <Widget>[
        for (final Category child in children)
          _NodeTile(
            category: child,
            depth: depth + 1,
            selectedId: selectedId,
            onSelect: onSelect,
            byParent: byParent,
            productCounts: productCounts,
            expandedIds: expandedIds,
          ),
      ],
    );
  }
}

/// Secili kategorinin kokten baslayan yolu, orn. "Elektronik / Telefon".
/// Secim yoksa veya kategori bulunamazsa bos metin doner.
String _breadcrumb(List<Category> categories, int? selectedId) {
  if (selectedId == null) {
    return '';
  }
  final Map<int, Category> byId = <int, Category>{
    for (final Category c in categories) c.id: c,
  };
  final List<String> parts = <String>[];
  Category? current = byId[selectedId];
  final Set<int> guard = <int>{};
  while (current != null && guard.add(current.id)) {
    parts.insert(0, current.name);
    final int? parentId = current.parentId;
    current = parentId == null ? null : byId[parentId];
  }
  return parts.join(' / ');
}

/// Secili kategorinin tum ust kimlikleri (genisletilecek dallar icin).
Set<int> _ancestorIds(List<Category> categories, int? selectedId) {
  final Set<int> ids = <int>{};
  if (selectedId == null) {
    return ids;
  }
  final Map<int, Category> byId = <int, Category>{
    for (final Category c in categories) c.id: c,
  };
  Category? current = byId[selectedId];
  final Set<int> guard = <int>{};
  while (current != null && guard.add(current.id)) {
    ids.add(current.id);
    final int? parentId = current.parentId;
    current = parentId == null ? null : byId[parentId];
  }
  return ids;
}
