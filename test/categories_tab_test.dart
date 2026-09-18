import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_management/db/app_database.dart';
import 'package:inventory_management/screens/categories_tab.dart';

// Kategori agaci saf mantigi icin birim testleri.
//
// Bilerek `testWidgets` DEGIL duz `test()` kullanilir: sqflite FFI
// future'lari widget testlerinin FakeAsync ortaminda pompa ile bile
// cozunmedigi icin gercek veritabanli widget testi bu yiginda yapisal
// olarak takilir. Agac kurma kurallari (kok gruplama, kardes siralama,
// yetim ve cevrim korumasi) ise saf fonksiyondur ve burada kilitlenir.
// Gercek DB okuma yollari (getAllCategories, countDirectProductsPerCategory,
// queryProducts) Linux masaustunde entegrasyon testiyle dogrulanir.
void main() {
  Category category(int id, String name, [int? parentId]) {
    return Category(
      id: id,
      name: name,
      parentId: parentId,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('buildCategoryChildrenMap', () {
    test('kokler null altinda toplanir, kardesler siralanir', () {
      final Map<int?, List<Category>> map = buildCategoryChildrenMap(
        <Category>[
          category(1, 'Zebra'),
          category(2, 'el Aletleri'),
          category(3, 'Elektrik', 2),
          category(4, 'Alet Cantasi', 2),
        ],
      );

      expect(
        map[null]!.map((Category c) => c.name),
        <String>['el Aletleri', 'Zebra'],
      );
      expect(
        map[2]!.map((Category c) => c.name),
        <String>['Alet Cantasi', 'Elektrik'],
      );
    });
  });

  group('buildCategoryNodes', () {
    test('hiyerarsi kurulur', () {
      final Map<int?, List<Category>> map = buildCategoryChildrenMap(
        <Category>[
          category(1, 'Kok'),
          category(2, 'Cocuk', 1),
          category(3, 'Torun', 2),
        ],
      );

      final List<CategoryNode> roots = buildCategoryNodes(map, null);

      expect(roots.map((CategoryNode n) => n.category.id), <int>[1]);
      expect(roots.single.children.single.category.id, 2);
      expect(roots.single.children.single.children.single.category.id, 3);
    });

    test('cevrimde yigin tasmasi olmaz, dugum bir kez yer alir', () {
      // A->B->A cevrimini elle kur: a'nin ustu b, b'nin ustu a.
      final Map<int?, List<Category>> map = <int?, List<Category>>{
        2: <Category>[category(1, 'A')],
        1: <Category>[category(2, 'B')],
      };

      final List<CategoryNode> nodes = buildCategoryNodes(map, 2);

      int count(CategoryNode node) {
        return 1 +
            node.children.fold<int>(
              0,
              (int acc, CategoryNode c) => acc + count(c),
            );
      }

      final int total =
          nodes.fold<int>(0, (int acc, CategoryNode n) => acc + count(n));
      expect(total, 2);
    });
  });

  group('findOrphanCategories', () {
    test('ustu listede olmayanlar bulunur ve siralanir', () {
      final List<Category> orphans = findOrphanCategories(<Category>[
        category(1, 'Kok'),
        category(2, 'Z Yetim', 99),
        category(3, 'A Yetim', 100),
        category(4, 'Cocuk', 1),
      ]);

      expect(
        orphans.map((Category c) => c.name),
        <String>['A Yetim', 'Z Yetim'],
      );
    });

    test('kokler ve erisilebilir cocuklar yetim sayilmaz', () {
      expect(
        findOrphanCategories(<Category>[
          category(1, 'Kok'),
          category(2, 'Cocuk', 1),
        ]),
        isEmpty,
      );
    });
  });
}
