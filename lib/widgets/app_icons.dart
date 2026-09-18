import 'package:flutter/material.dart';

/// Stroke-tarzi ikon sabitleri.
///
/// Neden emoji yok:
/// Proje kurali geregi arayuzde emoji kesinlikle yasaktir. Emojiler
/// platformdan platforma farkli cizilir, ciddiyetsiz gorunur ve renk
/// paletini bozar. Bunun yerine yalnizca Flutter Material Icons
/// kutuphanesindeki ince hatli (outline) vektor ikonlar kullanilir.
/// Bu ikonlar geometrik, tek renkli ve cozunurlukten bagimsizdir;
/// karanlik tema renkleriyle (kemik beyazi / notr gri) uyumludur.
///
/// Kullanim:
/// ```dart
/// Icon(AppIcons.edit, size: 20, color: AppColors.boneWhiteDim);
/// ```
abstract final class AppIcons {
  /// Urunler / envanter.
  static const IconData products = Icons.inventory_2_outlined;

  /// Gorseli olmayan urun icin yer tutucu.
  static const IconData productPlaceholder = Icons.inventory_2_outlined;

  /// Kategori agaci kok simgesi.
  static const IconData categories = Icons.category_outlined;

  /// Kapali klasor (kategori).
  static const IconData folder = Icons.folder_outlined;

  /// Acik klasor (genisletilmis kategori).
  static const IconData folderOpen = Icons.folder_open_outlined;

  /// Yeni kategori olusturma.
  static const IconData addCategory = Icons.create_new_folder_outlined;

  /// Genel ekleme.
  static const IconData add = Icons.add;

  /// Duzenleme.
  static const IconData edit = Icons.edit_outlined;

  /// Silme.
  static const IconData delete = Icons.delete_outline;

  /// Arama.
  static const IconData search = Icons.search;

  /// Siralama.
  static const IconData sort = Icons.sort;

  /// Liste filtreleme.
  static const IconData filter = Icons.filter_list;

  /// Urun gorseli / galeri.
  static const IconData image = Icons.image_outlined;

  /// Kamera ile gorsel cekme.
  static const IconData camera = Icons.photo_camera_outlined;

  /// Dosya secimi.
  static const IconData file = Icons.attach_file;

  /// Kapatma.
  static const IconData close = Icons.close;

  /// Onay / basarili islem.
  static const IconData check = Icons.check;

  /// Bilgi.
  static const IconData info = Icons.info_outline;

  /// Uyari (kritik stok, dogrulama).
  static const IconData warning = Icons.warning_amber_outlined;

  /// Saga isaret (breadcrumb ayraci yerine liste oku).
  static const IconData chevronRight = Icons.chevron_right;

  /// Geri donus.
  static const IconData back = Icons.arrow_back;

  /// Ek secenekler menusu.
  static const IconData more = Icons.more_vert;

  /// Varsayilan ikon boyutu.
  static const double defaultSize = 20;
}
