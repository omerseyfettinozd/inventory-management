import 'dart:io';

import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../services/image_store.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';

/// Dusuk stok esigi. Adet bu degerin altindaysa rozet vurgulanir.
const int kLowStockThreshold = 5;

/// Envanter listesindeki tek urun satiri.
///
/// - Kart zemini #141414, kenarlik #262626 (tema kart stili).
/// - Sol tarafta gorsel kucuk resmi; gorsel yoksa veya dosya
///   cozulemezse ince hatli yer tutucu ikon kutusu gosterilir.
/// - Baslik urun adi (kemik beyazi), alt satir kategori yolu ve
///   kisaltilmis aciklama (notr gri).
/// - Sag tarafta adet rozeti (tek aralikli rakam) ile duzenle / sil
///   ikon butonlari bulunur.
/// - Tum rakam iceren metinlerde [FontFeature.tabularFigures] kullanilir.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.categoryPath,
    this.imageStore,
    required this.onEdit,
    required this.onDelete,
  });

  /// Gosterilecek urun kaydi.
  final Product product;

  /// Kategori hiyerarsi yolu, orn. "Elektronik / Telefon".
  /// Bos ise yalnizca aciklama gosterilir.
  final String categoryPath;

  /// Goreceli [Product.imagePath] degerini mutlak [File] karsiligina
  /// cevirmek icin kullanilir. Null ise gorsel her zaman yer tutucu
  /// olarak cizilir (testler ve onizleme icin kullanislidir).
  final ImageStore? imageStore;

  /// Duzenle butonu tetikleyicisi.
  final VoidCallback onEdit;

  /// Sil butonu tetikleyicisi. Cagiran taraf silmeden once
  /// [ConfirmDeleteDialog] ile onay almalidir.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final File? imageFile = imageStore?.resolve(product.imagePath);
    final bool hasImage =
        imageFile != null &&
        (product.imagePath != null && product.imagePath!.trim().isNotEmpty);

    final int quantity = product.quantity;
    final bool isOutOfStock = quantity <= 0;
    final bool isLowStock =
        !isOutOfStock && quantity <= kLowStockThreshold;

    final Color badgeBorder = isOutOfStock
        ? AppColors.danger
        : (isLowStock ? AppColors.warning : AppColors.border);
    final Color badgeTextColor = isOutOfStock
        ? AppColors.danger
        : (isLowStock ? AppColors.warning : AppColors.secondaryText);

    final String badgeLabel = isOutOfStock
        ? 'Tukendi'
        : (isLowStock ? '$quantity adet - Kritik' : '$quantity adet');

    final String description = product.description.trim();

    return Card(
      child: ListTile(
        leading: _Thumbnail(hasImage: hasImage, imageFile: imageFile),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.boneWhite,
            fontWeight: FontWeight.w600,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (categoryPath.trim().isNotEmpty)
              Text(
                categoryPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontFeatures: <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontFeatures: <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeBorder),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Duzenle',
              icon: const Icon(AppIcons.edit, size: AppIcons.defaultSize),
              color: AppColors.boneWhiteDim,
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(AppIcons.delete, size: AppIcons.defaultSize),
              color: AppColors.boneWhiteDim,
              onPressed: onDelete,
            ),
          ],
        ),
        isThreeLine: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
      ),
    );
  }
}

/// Urun gorseli kucuk resmi veya yer tutucu ikon kutusu.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.hasImage, required this.imageFile});

  final bool hasImage;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasImage && imageFile != null
            ? Image.file(
                imageFile!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return const _PlaceholderBox();
                    },
              )
            : const _PlaceholderBox(),
      ),
    );
  }
}

/// Gorseli olmayan urunler icin ince hatli ikon kutusu.
class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        AppIcons.productPlaceholder,
        size: 24,
        color: AppColors.secondaryText,
      ),
    );
  }
}
