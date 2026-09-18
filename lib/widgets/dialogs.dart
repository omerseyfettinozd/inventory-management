import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'app_icons.dart';

/// Yeni kategori olusturma geri cagrisi.
///
/// Durum yonetimi katmaninin ([InventoryProvider.addCategory]) imzasiyla
/// birebir uyumludur:
/// ```dart
/// Future<int?> addCategory(String name, {int? parentId});
/// ```
/// Diyalog su sekilde baglanir:
/// ```dart
/// final yeniId = await AddCategoryDialog.show(
///   context,
///   categories: kategoriler,
///   onCreate: provider.addCategory,
/// );
/// ```
/// Basarisizlikta `null` doner; hata mesaji saglayicinin `lastError` alanindadir.
typedef CreateCategoryCallback =
    Future<int?> Function(String name, {int? parentId});

/// Kategori yeniden adlandirma geri cagrisi.
///
/// [InventoryProvider.renameCategory] imzasiyla birebir uyumludur:
/// ```dart
/// Future<bool> renameCategory(int id, String name);
/// ```
typedef RenameCategoryCallback = Future<bool> Function(int id, String name);

// ---------------------------------------------------------------------------
// Silme onayi
// ---------------------------------------------------------------------------

/// Urun silme onay diyalogu.
///
/// Metin sartnameye birebir uyar:
/// "Bu urunu envanterden silmek istediginize emin misiniz?"
/// Butonlar: "Iptal" (vazgec) ve "Sil" (onayla).
/// `true` onay, `false` vazgecme anlamina gelir; diyalog disina
/// dokunarak kapatma `false` sayilir.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({super.key, required this.productName});

  /// Silinecek urunun adi (bilgilendirme metninde gosterilir).
  final String productName;

  /// Diyalogu gosterir, onay sonucunu dondurur.
  static Future<bool> show(BuildContext context, String productName) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) =>
          ConfirmDeleteDialog(productName: productName),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ürünü sil'),
      content: Text(
        'Bu ürünü envanterden silmek istediğinize emin misiniz?\n\n'
        '"$productName" kalıcı olarak silinecek ve ilişkili görsel '
        'dosyasi temizlenecektir.',
        style: const TextStyle(
          color: AppColors.boneWhiteDim,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(AppIcons.delete, size: 18),
          label: const Text('Sil'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.background,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kategori ekleme
// ---------------------------------------------------------------------------

/// Urun formundan ayrilmadan kategori olusturma diyologu.
///
/// - Isim alani ([Validators.validateCategoryName] ile dogrulanir).
/// - Ust kategori acilir listesi (bos birakilirsa ana kategori olur).
/// - "Kaydet" basarili olursa yeni kategori kimligini dondurur;
///   "Iptal" veya disari dokunma null dondurur.
/// - Kayit hatasi (orn. ust kategori silinmis) diyalog icinde
///   satir ici hata metni olarak gosterilir, diyalog kapanmaz.
class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({
    super.key,
    this.parentId,
    required this.categories,
    required this.onCreate,
  });

  /// Onsecili ust kategori kimligi (urun formundaki mevcut secim).
  final int? parentId;

  /// Ust kategori listesinde gosterilecek tum kategoriler.
  final List<Category> categories;

  /// Kaydetme islemi. Yeni satir kimligini dondurmelidir.
  final CreateCategoryCallback onCreate;

  /// Diyalogu gosterir; yeni kategori kimligini veya null dondurur.
  static Future<int?> show(
    BuildContext context, {
    int? parentId,
    required List<Category> categories,
    required CreateCategoryCallback onCreate,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => AddCategoryDialog(
        parentId: parentId,
        categories: categories,
        onCreate: onCreate,
      ),
    );
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int? _selectedParentId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _selectedParentId = widget.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final int? id = await widget.onCreate(
        _nameController.text.trim(),
        parentId: _selectedParentId,
      );
      if (!mounted) {
        return;
      }
      if (id == null) {
        setState(() {
          _saving = false;
          _error = 'Kategori kaydedilemedi.';
        });
        return;
      }
      Navigator.of(context).pop(id);
    } on ArgumentError catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.message}';
      });
    } on StateError catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Kategori kaydedilemedi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<int?>> items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        child: Text('Ust kategori yok (ana kategori)'),
      ),
      ..._orderedWithDepth(widget.categories).map(
        (({Category category, int depth}) entry) => DropdownMenuItem<int?>(
          value: entry.category.id,
          child: Text(
            '${'  ' * entry.depth}${entry.category.name}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return AlertDialog(
      title: const Text('Kategori Ekle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Kategori adı',
                  hintText: 'Örn. Elektronik',
                  prefixIcon: Icon(AppIcons.folder),
                ),
                validator: Validators.validateCategoryName,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                // `initialValue` + secime bagli anahtar: diyalog acikken
                // ust secim degisirse alan yeniden kurulur.
                // `isExpanded`: uzun kategori adlari tasmaya yol acmaz.
                key: ValueKey<int?>(_selectedParentId),
                isExpanded: true,
                initialValue: _selectedParentId,
                decoration: const InputDecoration(
                  labelText: 'Üst kategori',
                  prefixIcon: Icon(AppIcons.categories),
                ),
                items: items,
                onChanged: _saving
                    ? null
                    : (int? value) {
                        setState(() {
                          _selectedParentId = value;
                        });
                      },
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.check, size: 18),
          label: Text(_saving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kategori yeniden adlandirma
// ---------------------------------------------------------------------------

/// Mevcut kategoriyi yeniden adlandirma diyologu.
///
/// Basarili olursa yeni adi dondurur, vazgecilirse null dondurur.
class RenameCategoryDialog extends StatefulWidget {
  const RenameCategoryDialog({
    super.key,
    required this.category,
    required this.onRename,
  });

  /// Yeniden adlandirilacak kategori.
  final Category category;

  /// Yeniden adlandirma islemi.
  final RenameCategoryCallback onRename;

  /// Diyalogu gosterir; yeni adi veya null dondurur.
  static Future<String?> show(
    BuildContext context, {
    required Category category,
    required RenameCategoryCallback onRename,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) =>
          RenameCategoryDialog(category: category, onRename: onRename),
    );
  }

  @override
  State<RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<RenameCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String next = _nameController.text.trim();
    if (next == widget.category.name.trim()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onRename(widget.category.id, next);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(next);
    } on ArgumentError catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.message}';
      });
    } on StateError catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Kategori guncellenemedi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kategoriyi Yeniden Adlandır'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Kategori adı',
                prefixIcon: Icon(AppIcons.edit),
              ),
              validator: Validators.validateCategoryName,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.check, size: 18),
          label: Text(_saving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bilgi / uyari
// ---------------------------------------------------------------------------

/// Genel bilgi ve uyari diyologu.
///
/// Dogrulama sonuclari ve kisa bilgilendirmeler icin tek butonlu
/// (varsayilan "Tamam") modaldir.
class InfoDialog extends StatelessWidget {
  const InfoDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Tamam',
  });

  /// Diyalog basligi.
  final String title;

  /// Aciklama metni.
  final String message;

  /// Kapatma butonu metni.
  final String buttonLabel;

  /// Diyalogu gosterir, kapatilana kadar bekler.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Tamam',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => InfoDialog(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: const TextStyle(
          color: AppColors.boneWhiteDim,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      actions: <Widget>[
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Yardimcilar
// ---------------------------------------------------------------------------

/// Kategorileri kokten yapraklara derinlik bilgisiyle siralar.
/// Dongusel referanslara karsi korumalidir (cevrimi kirar).
List<({Category category, int depth})> _orderedWithDepth(
  List<Category> categories,
) {
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
  final List<({Category category, int depth})> ordered =
      <({Category category, int depth})>[];
  final Set<int> visited = <int>{};

  void visit(Category category, int depth) {
    if (!visited.add(category.id)) {
      return;
    }
    ordered.add((category: category, depth: depth));
    for (final Category child in byParent[category.id] ?? <Category>[]) {
      visit(child, depth + 1);
    }
  }

  for (final Category root in byParent[null] ?? <Category>[]) {
    visit(root, 0);
  }
  // Yetim kategoriler (ust kaydi listede yok) en sonda kok seviyesinde.
  for (final Category c in categories) {
    if (!visited.contains(c.id)) {
      visit(c, 0);
    }
  }
  return ordered;
}
