// Inventory Management — kategori agaci sekmesi.
//
// Kategorileri hiyerarsik agac olarak gosterir (kok -> alt kategori).
// Her dugum genisletilebilir: isim, alt agactaki urun sayisi, dogrudan
// urunler (ad + adet) ve alt-kategori-ekle, yeniden adlandir, sil islemleri
// bulunur. Urunu olmayan kategoride "Bu kategoride ürün yok." gosterilir.
//
// Kurallar:
// - SADECE karanlik mod (renkler [AppColors] uzerinden).
// - Emoji yok; yalnizca Material ikonlar ve tipografik metin.
// - Rakamlar tabular hizali (FontFeature.tabularFigures).
// - Tum UI metinleri Turkce.
// - Gorsel dosyasi islemi yoktur; kategori silme yalnizca veritabani
//   kaydini kaldirir (urun iceren kategori silinemez).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/product_thumbnail.dart';

/// Duz kategori listesini `parentId -> cocuklar` haritasi olarak kurar.
///
/// Agac kurmanin ilk adimidir; kok kategoriler `null` anahtari altinda
/// toplanir. Yetim kalan (ust kaydi listede olmayan) kategoriler kok
/// seviyesinde listelenir. Her kardes grubu ada gore siralanir.
Map<int?, List<Category>> buildCategoryChildrenMap(
  List<Category> categories,
) {
  final Map<int?, List<Category>> map = <int?, List<Category>>{};
  for (final Category category in categories) {
    (map[category.parentId] ??= <Category>[]).add(category);
  }
  for (final List<Category> siblings in map.values) {
    siblings.sort(
      (Category a, Category b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }
  return map;
}

/// `parentId -> cocuklar` haritasindan [CategoryNode] agaci kurar.
///
/// [parentId] `null` ise kok dugumler dondurulur. Bozuk verideki cevrimlere
/// (A->B->A) karsi ziyaret kumesiyle korunur; cevrimli dugum yalnizca ilk
/// goruldugu yerde yer alir, yigim tasması olusmaz.
List<CategoryNode> buildCategoryNodes(
  Map<int?, List<Category>> childrenMap, [
  int? parentId,
  Set<int>? visited,
]) {
  visited ??= <int>{};
  final List<Category> children = childrenMap[parentId] ?? const <Category>[];
  return <CategoryNode>[
    for (final Category child in children)
      if (visited.add(child.id))
        CategoryNode(
          child,
          buildCategoryNodes(childrenMap, child.id, visited),
        ),
  ];
}

/// Ust kaydi listede olmayan kategorileri bulur.
///
/// Agac yuruyusu kokten (`null`) basladigi icin bu kayitlar normalde
/// dusurulurdu; kok seviyesine eklenerek urunleri erisilebilir tutulur.
List<Category> findOrphanCategories(List<Category> categories) {
  final Set<int> ids = <int>{for (final Category c in categories) c.id};
  final List<Category> orphans = <Category>[
    for (final Category c in categories)
      if (c.parentId != null && !ids.contains(c.parentId)) c,
  ];
  orphans.sort(
    (Category a, Category b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return orphans;
}

/// Kategori agacini yoneten sekme.
///
/// Urun formundaki kategori seciminden bagimsizdir; ancak buradaki
/// [AddCategoryDialog] ayni sinif oldugu icin urun formu tarafindan da
/// yeniden kullanilabilir.
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  List<CategoryNode> _roots = const <CategoryNode>[];
  Map<int, int> _productCounts = const <int, int>{};
  Map<int, List<Product>> _productsByCategory = const <int, List<Product>>{};
  int _totalCategories = 0;
  bool _loading = true;
  String? _error;

  /// Artan yukleme sirasi. Eski yukleme gec donerse sonucu yoksayilir;
  /// bayragin sahipligi her zaman en son yuklemededir.
  int _reloadSeq = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final int seq = ++_reloadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AppDatabase db = AppDatabase();
      final List<Category> flat = await db.getAllCategories();
      final Map<int?, List<Category>> childrenMap =
          buildCategoryChildrenMap(flat);
      final Set<int> visited = <int>{};
      final List<CategoryNode> roots = buildCategoryNodes(
        childrenMap,
        null,
        visited,
      );
      // Yetimler kokte listelenir (urunleri erisilebilir kalir).
      for (final Category orphan in findOrphanCategories(flat)) {
        if (visited.add(orphan.id)) {
          roots.add(
            CategoryNode(
              orphan,
              buildCategoryNodes(childrenMap, orphan.id, visited),
            ),
          );
        }
      }
      // Tek GROUP BY sorgusu + bellek ici alt-agac toplami (N+1 yerine).
      final Map<int, int> direct =
          await db.countDirectProductsPerCategory();
      final Map<int, int> counts = <int, int>{};
      int sum(CategoryNode node) {
        int total = direct[node.category.id] ?? 0;
        for (final CategoryNode child in node.children) {
          total += sum(child);
        }
        counts[node.category.id] = total;
        return total;
      }

      for (final CategoryNode root in roots) {
        sum(root);
      }
      // Tek sorguda tum urunler + bellek ici gruplama (N+1 yerine).
      // Her kategori satiri kendi dogrudan urunlerini gosterir.
      final List<Product> allProducts = await db.queryProducts();
      final Map<int, List<Product>> grouped = <int, List<Product>>{};
      for (final Product product in allProducts) {
        (grouped[product.categoryId] ??= <Product>[]).add(product);
      }
      if (!mounted || seq != _reloadSeq) {
        return;
      }
      setState(() {
        _roots = roots;
        _productCounts = counts;
        _productsByCategory = grouped;
        _totalCategories = flat.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reloadSeq) {
        return;
      }
      setState(() {
        _error = 'Kategoriler yüklenemedi: $e';
        _loading = false;
      });
    } finally {
      // Bayrak her durumda kapanir: basari ve hata yollari kendi
      // setState'inde kapatir; erken donuslerde burasi kapatir.
      // Dispose sonrasi setState yasaktir, eski yukleme ise bayragin
      // sahibine (en son yuklemeye) dokunmaz.
      if (mounted && seq == _reloadSeq && _loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Envanter sekmesinin filtre agacini tazeler.
  ///
  /// Bu sekme dogrudan AppDatabase yazar; provider listesini de
  /// senkronize etmezse Envanter sekmesi eski kumeyi gosterir.
  /// En iyi cabadir: basarisizligi sessiz gecilir, sekme kendi durumunu korur.
  Future<void> _syncProvider() async {
    if (!mounted) {
      return;
    }
    try {
      await context.read<InventoryProvider>().loadAll();
    } catch (_) {
      // Bilincli olarak sessiz gecilir (bkz. dokumantasyon).
    }
  }

  Future<void> _onAdd(int? parentId, String? parentName) async {
    final int? newId = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => AddCategoryDialog(
        parentId: parentId,
        parentName: parentName,
      ),
    );
    if (!mounted || newId == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kategori eklendi.')),
    );
    await _reload();
  }

  Future<void> _onRename(Category category) async {
    final String? nextName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _RenameCategoryDialog(
        currentName: category.name,
      ),
    );
    if (!mounted || nextName == null || nextName == category.name) {
      return;
    }
    try {
      await AppDatabase().updateCategoryName(category.id, nextName);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori adı güncellendi.')),
      );
      await _reload();
      await _syncProvider();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeniden adlandırma başarısız: $e')),
      );
    }
  }

  Future<void> _onDelete(Category category) async {
    final AppDatabase db = AppDatabase();
    int count = _productCounts[category.id] ?? 0;
    try {
      count = await db.countProductsInCategory(category.id);
    } catch (_) {
      // Sayac okunamazsa onbellekteki degerle devam edilir.
    }
    if (!mounted) {
      return;
    }
    if (count > 0) {
      // Urun iceren kategori silinemez: engelleyen uyari.
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Kategori silinemez'),
          content: Text(
            'Bu kategoride ve alt kategorilerinde $count ürün bulunuyor. '
            'Silmek için önce ürünleri başka bir kategoriye taşıyın '
            'veya ürünleri silin.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Kategoriyi sil'),
            content: Text(
              '"${category.name}" kategorisini silmek istediğinize emin '
              'misiniz? Bu işlem alt kategorileri de kalıcı olarak siler.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await db.deleteCategory(category.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori silindi.')),
      );
      await _reload();
      await _syncProvider();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silme başarısız: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onAdd(null, null),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  label: const Text('Kök Kategori Ekle'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _reload,
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Toplam $_totalCategories kategori',
            style: tabularTextStyle(textTheme.bodySmall)?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody(textTheme)),
      ],
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final String? error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.secondaryText,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _reload,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (_roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.folder_outlined,
                size: 48,
                color: AppColors.secondaryText,
              ),
              const SizedBox(height: 12),
              Text(
                'Henüz kategori oluşturulmadı.',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Ürünleri düzenlemek için önce bir kategori ekleyin.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _onAdd(null, null),
                child: const Text('İlk Kategoriyi Ekle'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: <Widget>[
        for (final CategoryNode root in _roots) _buildNode(root, 0, textTheme),
      ],
    );
  }

  Widget _buildNode(CategoryNode node, int depth, TextTheme textTheme) {
    final Category category = node.category;
    final int productCount = _productCounts[category.id] ?? 0;
    final String subtitle =
        '$productCount ürün · ${node.children.length} alt kategori';
    final List<Product> products =
        _productsByCategory[category.id] ?? const <Product>[];

    Widget titleRow() {
      return Row(
        children: <Widget>[
          const Icon(
            Icons.folder_outlined,
            size: 18,
            color: AppColors.boneWhiteDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
        ],
      );
    }

    Widget actions() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: () => _onAdd(category.id, category.name),
            tooltip: 'Alt kategori ekle',
            icon: const Icon(Icons.add, size: 20),
          ),
          IconButton(
            onPressed: () => _onRename(category),
            tooltip: 'Yeniden adlandır',
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            onPressed: () => _onDelete(category),
            tooltip: 'Sil',
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.danger,
            ),
          ),
        ],
      );
    }

    Widget productRow(Product product) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
        child: Row(
          children: <Widget>[
            ProductThumbnail(
              relativePath: product.imagePath,
              size: 36,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Adet: ${product.quantity}',
              style: tabularTextStyle(textTheme.bodySmall)?.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    final OutlinedBorder tileShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    );

    // Her kategori satiri genisletilebilir: once dogrudan urunler
    // (ad + adet), sonra alt kategoriler listelenir.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        collapsedBackgroundColor: AppColors.card,
        backgroundColor: AppColors.card,
        collapsedShape: tileShape,
        shape: tileShape,
        title: titleRow(),
        subtitle: Text(
          subtitle,
          style: tabularTextStyle(textTheme.bodySmall)?.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        trailing: actions(),
        children: <Widget>[
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Bu kategoride ürün yok.'),
              ),
            )
          else
            for (final Product product in products) productRow(product),
          for (final CategoryNode child in node.children)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: _buildNode(child, depth + 1, textTheme),
            ),
        ],
      ),
    );
  }
}

/// Yeni kategori olusturma diyalogu.
///
/// [parentId] `null` ise kok kategori, dolu ise ilgili kategorinin alt
/// kategorisi olusturulur. Urun ekleme/duzenleme formundaki "Kategori Ekle"
/// butonu da ayni diyalogu kullanir; boylece formdan ayrilmadan kategori
/// acilabilir. Basarili kayitta yeni satir kimligi ile kapanir
/// (`Navigator.pop(context, newId)`); vazgecmede `null` doner.
class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key, this.parentId, this.parentName});

  /// Ust kategori kimligi. Kok kategori icin `null`.
  final int? parentId;

  /// Bilgi amacli ust kategori adi (baslikta gosterilir).
  final String? parentName;

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final int newId = await AppDatabase().insertCategory(
        name: _nameController.text,
        parentId: widget.parentId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(newId);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _formError = 'Kategori eklenemedi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? parentName = widget.parentName;
    return AlertDialog(
      title: Text(
        parentName == null ? 'Kök Kategori Ekle' : 'Alt Kategori Ekle',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (parentName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Üst kategori: $parentName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
              ),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Kategori adı',
                hintText: 'Örn. El Aletleri',
              ),
              validator: Validators.validateCategoryName,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                      ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Ekleniyor' : 'Ekle'),
        ),
      ],
    );
  }
}

/// Kategori yeniden adlandirma diyalogu.
///
/// Gecerli isim dondurur; vazgecmede `null` doner. Veritabani guncellemesi
/// cagiran tarafta yapilir.
class _RenameCategoryDialog extends StatefulWidget {
  const _RenameCategoryDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kategoriyi Yeniden Adlandır'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Kategori adı',
          ),
          validator: Validators.validateCategoryName,
          onFieldSubmitted: (_) {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
