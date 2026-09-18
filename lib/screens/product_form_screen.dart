import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../db/app_database.dart';
import '../services/image_store.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// Urun ekleme / duzenleme formu.
///
/// [product] null ise ekleme modunda, dolu ise duzenleme modunda acilir.
/// Duzenleme modunda tum alanlar (gorsel, isim, aciklama, adet, kategori)
/// mevcut degerlerle onceden doldurulur.
///
/// Kalicilik dogrudan [AppDatabase] + [ImageStore] uzerinden yurur:
/// gorseller `images/` altina kopyalanir, veritabaninda yalnizca goreceli
/// yol tutulur. Kayit basarili olursa `true` ile kapatilir (`pop(true)`);
/// liste ekranlari bu sonucu izleyip listeyi tazeleyebilir.
///
/// Tema: yalnizca karanlik mod ([AppTheme.darkTheme]). Emoji kullanilmaz;
/// yalnizca Material ikonlari ve tipografik metinler kullanilir.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    this.product,
    AppDatabase? database,
    ImageStore? imageStore,
  })  : _database = database,
        _imageStore = imageStore;

  /// Duzenlenecek urun. Null ise yeni urun eklenir.
  final Product? product;

  final AppDatabase? _database;
  final ImageStore? _imageStore;

  /// Ekleme modu mu?
  bool get isEdit => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;

  late final AppDatabase _db;
  late final ImageStore _imageStore;
  final ImagePicker _imagePicker = ImagePicker();

  List<Category> _categories = <Category>[];
  bool _loadingCategories = true;
  String? _categoriesError;

  int? _selectedCategoryId;

  /// Bu oturumda secilen yeni gorsel dosyasi (henuz uygulamaya kopyalanmadi).
  File? _pickedFile;

  /// Duzenleme modunda mevcut gorselin kaldirilmasi istendi mi?
  bool _removeExisting = false;

  bool _saving = false;
  bool _storeReady = false;

  bool get _isEdit => widget.product != null;

  bool get _isMobile {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _db = widget._database ?? AppDatabase();
    _imageStore = widget._imageStore ?? ImageStore();

    final Product? product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController =
        TextEditingController(text: product?.description ?? '');
    _quantityController = TextEditingController(
      text: product != null ? product.quantity.toString() : '0',
    );
    _selectedCategoryId = product?.categoryId;

    _initStore();
    _loadCategories();
  }

  Future<void> _initStore() async {
    if (_imageStore.isInitialized) {
      if (mounted) {
        setState(() => _storeReady = true);
      }
      return;
    }
    try {
      await _imageStore.init();
    } on Exception {
      // Gorsel onizleme calismazsa form kilitlenmemeli; kayit sirasinda
      // init yeniden denenecek.
      return;
    }
    if (mounted) {
      setState(() => _storeReady = true);
    }
  }

  Future<void> _loadCategories({int? selectId}) async {
    if (mounted) {
      setState(() {
        _loadingCategories = true;
        _categoriesError = null;
      });
    }
    try {
      final List<Category> categories = await _db.getAllCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _loadingCategories = false;
        if (selectId != null) {
          _selectedCategoryId = selectId;
        } else if (_selectedCategoryId != null &&
            categories.every((Category c) => c.id != _selectedCategoryId)) {
          // Secili kategori artik yoksa secimi koru (duzenleme modunda
          // dropdown yine de gecerli gosterim yapar); yeni secim zorunlu degil.
        }
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingCategories = false;
        _categoriesError = 'Kategoriler yüklenemedi: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // Kategori yol adlari ("Elektronik / Telefon")
  // -----------------------------------------------------------------

  String _categoryPath(Category category, Map<int, Category> byId) {
    final List<String> parts = <String>[category.name];
    final Set<int> seen = <int>{category.id};
    int? parentId = category.parentId;
    while (parentId != null) {
      final Category? parent = byId[parentId];
      if (parent == null || !seen.add(parent.id)) {
        break;
      }
      parts.insert(0, parent.name);
      parentId = parent.parentId;
    }
    return parts.join(' / ');
  }

  List<MapEntry<int, String>> _sortedCategoryEntries() {
    final Map<int, Category> byId = <int, Category>{
      for (final Category c in _categories) c.id: c,
    };
    final List<MapEntry<int, String>> entries = _categories
        .map((Category c) => MapEntry<int, String>(c.id, _categoryPath(c, byId)))
        .toList();
    entries.sort(
      (MapEntry<int, String> a, MapEntry<int, String> b) =>
          a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return entries;
  }

  // -----------------------------------------------------------------
  // Gorsel secimi
  // -----------------------------------------------------------------

  Future<void> _pickImage() async {
    if (_isMobile) {
      await _showMobileImageSourceSheet();
    } else {
      await _pickViaFilePicker();
    }
  }

  Future<void> _showMobileImageSourceSheet() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden Seç'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Kamerayla Çek'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _pickedFile = File(picked.path);
        _removeExisting = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      _showError('Görsel seçilemedi: ${e.message ?? 'bilinmeyen hata'}');
    }
  }

  Future<void> _pickViaFilePicker() async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      final String? path = result.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      setState(() {
        _pickedFile = File(path);
        _removeExisting = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      _showError('Dosya seçilemedi: ${e.message ?? 'bilinmeyen hata'}');
    }
  }

  void _clearImage() {
    setState(() {
      _pickedFile = null;
      _removeExisting = true;
    });
  }

  /// Onizlemede gosterilecek dosya: yeni secim varsa o, yoksa kayitli gorsel.
  File? _previewFile() {
    if (_pickedFile != null) {
      return _pickedFile;
    }
    if (_removeExisting || !_storeReady) {
      return null;
    }
    final String? relative = widget.product?.imagePath;
    if (relative == null || relative.trim().isEmpty) {
      return null;
    }
    try {
      final File? file = _imageStore.resolve(relative);
      if (file != null && file.existsSync()) {
        return file;
      }
    } on StateError {
      return null;
    }
    return null;
  }

  bool get _hasImage => _previewFile() != null;

  // -----------------------------------------------------------------
  // Kaydetme
  // -----------------------------------------------------------------

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _adjustQuantity(int delta) {
    final int current =
        Validators.parseQuantity(_quantityController.text) ?? 0;
    final int next = (current + delta).clamp(0, 9999999);
    _quantityController.text = next.toString();
    _quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: _quantityController.text.length),
    );
  }

  Future<void> _openAddCategoryDialog() async {
    final int? newId = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return _AddCategoryDialog(
          database: _db,
          categories: _categories,
          initialParentId: _selectedCategoryId,
        );
      },
    );
    if (newId == null || !mounted) {
      return;
    }
    // Form kapatilmadan liste tazelenir ve yeni kategori secilir.
    await _loadCategories(selectId: newId);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Kategori seçimi zorunludur.');
      return;
    }
    final int? quantity = Validators.parseQuantity(_quantityController.text);
    if (quantity == null || quantity < 0) {
      _showError('Adet negatif olamaz.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (!_imageStore.isInitialized) {
        await _imageStore.init();
      }

      final String name = _nameController.text.trim();
      final String description = _descriptionController.text.trim();
      final int categoryId = _selectedCategoryId!;
      final Product? existing = widget.product;

      if (existing == null) {
        String? imageRelative;
        if (_pickedFile != null) {
          imageRelative = await _imageStore.saveImage(_pickedFile!);
        }
        try {
          await _db.insertProduct(
            name: name,
            description: description,
            quantity: quantity,
            categoryId: categoryId,
            imagePath: imageRelative,
          );
        } catch (_) {
          // Kayit basarisizsa kopyalanan gorsel yetim kalmasin.
          await _imageStore.deleteByRelative(imageRelative);
          rethrow;
        }
      } else {
        String? imageRelative = existing.imagePath;
        String? newRelative;
        bool clearImage = false;
        if (_pickedFile != null) {
          // Once yeniyi kaydet; DB yazimi basarili olursa eski silinir.
          // Boylece DB hatasinda eski gorsel korunur.
          newRelative = await _imageStore.saveImage(_pickedFile!);
          imageRelative = newRelative;
        } else if (_removeExisting) {
          imageRelative = null;
          clearImage = true;
        }
        try {
          await _db.updateProduct(
            id: existing.id,
            name: name,
            description: description,
            quantity: quantity,
            categoryId: categoryId,
            imagePath: imageRelative,
            clearImage: clearImage,
          );
        } catch (_) {
          // DB yazimi basarisizsa yeni kopyayi geri al (eski korunur).
          await _imageStore.deleteByRelative(newRelative);
          rethrow;
        }
        // Commit basarili: eski dosyalari temizle.
        if (newRelative != null &&
            existing.imagePath != null &&
            existing.imagePath != newRelative) {
          await _imageStore.deleteByRelative(existing.imagePath);
        } else if (_removeExisting) {
          await _imageStore.deleteByRelative(existing.imagePath);
        }
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Ürün güncellendi.' : 'Ürün kaydedildi.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ImageStoreException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        _showError('${e.message}');
      }
    } on StateError catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } on FileSystemException {
      if (mounted) {
        _showError('Görsel dosyası işlenirken bir hata oluştu.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // -----------------------------------------------------------------
  // Arayuz
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ürünü Düzenle' : 'Ürün Ekle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildImageSection(context),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Ürün İsmi',
                  hintText: 'Örn. USB-C Kablo 1 m',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: Validators.validateProductName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                minLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Ürünle ilgili notlar (isteğe bağlı)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: Validators.validateDescription,
              ),
              const SizedBox(height: 12),
              _buildQuantityField(context),
              const SizedBox(height: 12),
              _buildCategoryField(context),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _saving
                      ? 'Kaydediliyor...'
                      : (_isEdit ? 'Değişiklikleri Kaydet' : 'Ürünü Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final File? preview = _hasImage ? _previewFile() : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Ürün Görseli',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: preview != null
              ? Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.file(preview, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: AppColors.background.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                        child: IconButton(
                          tooltip: 'Görseli Kaldır',
                          icon: const Icon(Icons.close, size: 18),
                          color: AppColors.boneWhite,
                          onPressed: _saving ? null : _clearImage,
                        ),
                      ),
                    ),
                  ],
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: AppColors.secondaryText,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Görsel seçilmedi',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: Icon(
                  _isMobile
                      ? Icons.photo_library_outlined
                      : Icons.upload_file_outlined,
                ),
                label: Text(
                  _isMobile ? 'Görsel Seç' : 'Dosya Seç',
                ),
              ),
            ),
            if (preview != null) ...<Widget>[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _clearImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Kaldır'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityField(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IconButton.outlined(
          tooltip: 'Azalt',
          icon: const Icon(Icons.remove),
          onPressed: _saving ? null : () => _adjustQuantity(-1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            textAlign: TextAlign.center,
            style: tabularTextStyle(Theme.of(context).textTheme.bodyLarge),
            decoration: const InputDecoration(
              labelText: 'Adet',
              hintText: '0',
              counterText: '',
            ),
            maxLength: 7,
            validator: Validators.validateQuantity,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Artır',
          icon: const Icon(Icons.add),
          onPressed: _saving ? null : () => _adjustQuantity(1),
        ),
      ],
    );
  }

  Widget _buildCategoryField(BuildContext context) {
    if (_loadingCategories) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_categoriesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _categoriesError!,
            style: const TextStyle(color: AppColors.danger),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _loadCategories(),
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Tekrar Dene'),
          ),
        ],
      );
    }

    final List<MapEntry<int, String>> entries = _sortedCategoryEntries();

    // Duzenleme modunda kategori silinmis olabilir; mevcut secim listede
    // yoksa gosterim icin gecici girdi eklenir.
    final List<MapEntry<int, String>> items = List.of(entries);
    final Product? product = widget.product;
    if (_selectedCategoryId != null &&
        items.every(
          (MapEntry<int, String> e) => e.key != _selectedCategoryId,
        )) {
      items.add(
        MapEntry<int, String>(
          _selectedCategoryId!,
          product != null
              ? 'Önceki kategori (id: ${product.categoryId})'
              : 'Seçili kategori',
        ),
      );
    }

    final Widget dropdown = DropdownButtonFormField<int>(
      // Kontrollu kullanim: "Kategori Ekle" sonrasi programatik
      // secim (selectId) ekrana yansimalidir. Yeni Flutter'da `value`
      // yerine `initialValue` kullanilir; secim degisince alanin
      // yeniden kurulmasi icin anahtar secime baglidir.
      // `isExpanded` sarttir: uzun (girintili) kategori adlari
      // alanin ic genisligini itip sag tasmaya yol acmamalidir.
      key: ValueKey<int?>(_selectedCategoryId),
      isExpanded: true,
      initialValue: _selectedCategoryId,
      hint: Text(
        entries.isEmpty ? 'Önce kategori oluşturun' : 'Kategori seçin',
        overflow: TextOverflow.ellipsis,
      ),
      decoration: const InputDecoration(
        labelText: 'Kategori',
        prefixIcon: Icon(Icons.folder_outlined),
      ),
      items: items
          .map(
            (MapEntry<int, String> e) => DropdownMenuItem<int>(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (int? value) {
              setState(() => _selectedCategoryId = value);
            },
      validator: (int? value) {
        if (value == null) {
          return 'Kategori seçimi zorunludur.';
        }
        return Validators.validateCategoryId(value);
      },
    );

    final Widget addButton = OutlinedButton.icon(
      onPressed: _saving ? null : _openAddCategoryDialog,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Kategori Ekle'),
    );

    // Dar ekranda (veya buyuk yazi tipinde) buton + alan yan yana
    // sigmiyorsa alta alta dizilir; sag tasma yapilmaz.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              dropdown,
              const SizedBox(height: 8),
              addButton,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: dropdown),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: addButton,
            ),
          ],
        );
      },
    );
  }
}

/// Form kapatilmadan kategori olusturmayi saglayan modal diyalog.
///
/// Isim + istege bagli ust kategori alir; basarili olursa yeni satir
/// kimligi (`int`) ile kapatilir. Paylasilan `AddCategoryDialog` bileseni
/// hazir oldugunda bu ozel diyalog onunla degistirilebilir; davranis sozlesmesi
/// aynidir: basarida yeni kategori id doner, vazgecmede null doner.
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({
    required this.database,
    required this.categories,
    this.initialParentId,
  });

  final AppDatabase database;
  final List<Category> categories;
  final int? initialParentId;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _parentId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    final int? initial = widget.initialParentId;
    _parentId = initial != null &&
            widget.categories.any((Category c) => c.id == initial)
        ? initial
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _categoryPath(Category category, Map<int, Category> byId) {
    final List<String> parts = <String>[category.name];
    final Set<int> seen = <int>{category.id};
    int? parentId = category.parentId;
    while (parentId != null) {
      final Category? parent = byId[parentId];
      if (parent == null || !seen.add(parent.id)) {
        break;
      }
      parts.insert(0, parent.name);
      parentId = parent.parentId;
    }
    return parts.join(' / ');
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final int newId = await widget.database.insertCategory(
        name: _nameController.text.trim(),
        parentId: _parentId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(newId);
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() => _error = '${e.message}');
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, Category> byId = <int, Category>{
      for (final Category c in widget.categories) c.id: c,
    };
    final List<Category> sorted = List.of(widget.categories)
      ..sort(
        (Category a, Category b) => _categoryPath(a, byId)
            .toLowerCase()
            .compareTo(_categoryPath(b, byId).toLowerCase()),
      );

    return AlertDialog(
      title: const Text('Kategori Ekle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Kategori Adı',
                  hintText: 'Örn. Telefon',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                validator: Validators.validateCategoryName,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _parentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Üst Kategori',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    child: Text('Yok (ana kategori)'),
                  ),
                  ...sorted.map(
                    (Category c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(
                        _categoryPath(c, byId),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (int? value) {
                        setState(() => _parentId = value);
                      },
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_saving ? 'Ekleniyor...' : 'Ekle'),
        ),
      ],
    );
  }
}
