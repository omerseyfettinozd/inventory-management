import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// Goreceli urun gorsel yolundan karesel kucuk resim gosteren paylasilabilir
/// widget.
///
/// Envanter karti ve kategori satiri ayni cozunurluk kurallarini kullanir:
/// yalnizca dosya adi dikkate alinir, uzanti izin listesinde olmalidir ve
/// cozumlenen yol `images/` dizini disina tasamaz. Dosya yoksa veya gorsel
/// tanimli degilse ince hatli yer tutucu ikon gosterilir.
class ProductThumbnail extends StatefulWidget {
  const ProductThumbnail({
    super.key,
    required this.relativePath,
    this.size = 64,
  });

  /// Veritabanindaki goreceli gorsel yolu (orn. `images/ornek.jpg`).
  final String? relativePath;

  /// Karenin kenar uzunlugu (mantiksal piksel).
  final double size;

  @override
  State<ProductThumbnail> createState() => _ProductThumbnailState();
}

class _ProductThumbnailState extends State<ProductThumbnail> {
  Future<File?>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _resolve();
  }

  @override
  void didUpdateWidget(covariant ProductThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _fileFuture = _resolve();
    }
  }

  static const Set<String> _allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  Future<File?> _resolve() async {
    final String? relative = widget.relativePath;
    if (relative == null || relative.trim().isEmpty) {
      return null;
    }
    // Dizin kacamasi savunmasi: yalnizca dosya adi kullanilir ve uzanti
    // izin listesinde olmalidir. Boylece '/etc/passwd' gibi mutlak yol
    // satirlari destek dizini disina cozulemez.
    final String sanitized = relative.trim().replaceAll('\\', '/');
    if (sanitized.contains('..')) {
      return null;
    }
    final String fileName = p.basename(sanitized);
    final String ext = p.extension(fileName).toLowerCase();
    final String bare = ext.startsWith('.') ? ext.substring(1) : ext;
    if (fileName.isEmpty || !_allowedExtensions.contains(bare)) {
      return null;
    }
    try {
      final Directory support = await getApplicationSupportDirectory();
      final String absolute =
          p.normalize(p.join(support.path, 'images', fileName));
      if (!p.isWithin(p.join(support.path, 'images'), absolute)) {
        return null;
      }
      final File file = File(absolute);
      return await file.exists() ? file : null;
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<File?>(
        future: _fileFuture,
        builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
          final File? file = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (file == null) {
            return const Icon(
              Icons.image_outlined,
              color: AppColors.secondaryText,
            );
          }
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_outlined,
              color: AppColors.secondaryText,
            ),
          );
        },
      ),
    );
  }
}
