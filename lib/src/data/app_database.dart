// ignore: depend_on_referenced_packages
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/bookmark.dart';
import '../models/bookmark_category.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'bmark.db';
  static const _version = 4;

  /// Distinct accent for the protected Vault category.
  static const _vaultColor = 0xFF7B61FF;

  static const bookmarks = 'bookmarks';
  static const categories = 'categories';

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  /// Closes the cached connection, if any. Test-only escape hatch so a test
  /// can simulate an upgrade from an older install.
  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE COLLATE NOCASE,
            color INTEGER NOT NULL DEFAULT 4286104288,
            is_default INTEGER NOT NULL DEFAULT 0,
            is_vault INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE $bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL DEFAULT 'Unknown',
            category_id INTEGER,
            thumbnail_url TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (category_id) REFERENCES $categories (id)
              ON DELETE SET NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_bookmarks_category ON $bookmarks (category_id)',
        );
        await db.execute(
          'CREATE UNIQUE INDEX idx_bookmarks_url ON $bookmarks (url)',
        );

        for (var i = 0; i < _seedCategories.length; i++) {
          final seed = _seedCategories[i];
          await db.insert(
            categories,
            {
              'name': seed.$1,
              'color': seed.$2,
              'is_default': 1,
              'is_vault': seed.$3 ? 1 : 0,
              'sort_order': i,
            },
          );
        }
      },
      onUpgrade: (db, from, to) async {
        // v2: user-defined ordering for the filter chips.
        if (from < 2) {
          await db.execute(
            'ALTER TABLE $categories ADD COLUMN sort_order '
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        // v3: heal databases that were created by the buggy v2 builder, which
        // reported version 2 but left the table without the ordering column.
        if (from < 3) {
          final info = await db.rawQuery(
            'PRAGMA table_info($categories)',
          );
          final hasSortOrder = info.any(
            (column) => column['name'] == 'sort_order',
          );
          if (!hasSortOrder) {
            await db.execute(
              'ALTER TABLE $categories ADD COLUMN sort_order '
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          await db.execute(
            'UPDATE $categories SET sort_order = id ' 
            'WHERE sort_order = 0',
          );
        }
        // v4: the protected Vault category. Existing installs get the column
        // and the category injected automatically, so no migration by hand is
        // needed and no bookmark is disturbed.
        if (from < 4) {
          final info = await db.rawQuery(
            'PRAGMA table_info($categories)',
          );
          final hasVault = info.any(
            (column) => column['name'] == 'is_vault',
          );
          if (!hasVault) {
            await db.execute(
              'ALTER TABLE $categories ADD COLUMN is_vault '
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          await _ensureVaultCategory(db);
        }
      },
    );
  }

  /// Makes sure the built-in Vault category exists, flagging an existing
  /// same-named category instead of creating a duplicate.
  static Future<void> _ensureVaultCategory(DatabaseExecutor db) async {
    final existing = await db.query(
      categories,
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [BookmarkCategory.vaultName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        categories,
        {'is_vault': 1, 'is_default': 1},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $categories',
    );
    final next = (result.first['next'] as num?)?.toInt() ?? 0;
    await db.insert(categories, {
      'name': BookmarkCategory.vaultName,
      'color': _vaultColor,
      'is_default': 1,
      'is_vault': 1,
      'sort_order': next,
    });
  }

  static const _seedCategories = <(String, int, bool)>[
    ('TikTok', 0xFF111111, false),
    ('Instagram', 0xFFE1306C, false),
    ('YouTube', 0xFFFF0000, false),
    ('Facebook', 0xFF1877F2, false),
    ('Twitter', 0xFF1DA1F2, false),
    ('Reddit', 0xFFFF4500, false),
    ('Other', 0xFF6C7AE0, false),
    (BookmarkCategory.vaultName, _vaultColor, true),
  ];

  // ---------------------------------------------------------------- categories

  Future<List<BookmarkCategory>> fetchCategories() async {
    final db = await database;
    final rows = await db.query(
      categories,
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(BookmarkCategory.fromMap).toList();
  }

  /// Persists a new category order. [orderedIds] is the list of category ids
  /// in the exact order the user dragged them into.
  Future<void> reorderCategories(List<int> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          categories,
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  Future<BookmarkCategory> addCategory(String name) async {
    final db = await database;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    final id = await db.insert(
      categories,
      {
        'name': trimmed,
        'color': _colorFor(trimmed),
        'is_default': 0,
        'is_vault': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id == 0) {
      // Already exists - return the existing row instead of creating a duplicate.
      final rows = await db.query(
        categories,
        where: 'name = ?',
        whereArgs: [trimmed],
        limit: 1,
      );
      return BookmarkCategory.fromMap(rows.first);
    }
    // New categories land at the end of the user's ordering.
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $categories',
    );
    final next = (result.first['next'] as num?)?.toInt() ?? 0;
    await db.update(
      categories,
      {'sort_order': next},
      where: 'id = ?',
      whereArgs: [id],
    );
    return BookmarkCategory(
      id: id,
      name: trimmed,
      colorValue: _colorFor(trimmed),
      sortOrder: next,
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    // Seeded categories (including the protected Vault) cannot be removed.
    await db.delete(
      categories,
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  Future<BookmarkCategory?> categoryByName(String name) async {
    final db = await database;
    final rows = await db.query(
      categories,
      where: 'name = ?',
      whereArgs: [name.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : BookmarkCategory.fromMap(rows.first);
  }

  // ----------------------------------------------------------------- bookmarks

  Future<List<Bookmark>> fetchBookmarks({int? categoryId}) async {
    final db = await database;
    final rows = await db.query(
      bookmarks,
      where: categoryId == null ? null : 'category_id = ?',
      whereArgs: categoryId == null ? null : [categoryId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  /// Returns the existing bookmark id when the URL was already saved, otherwise
  /// inserts a new row and returns its id.
  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return db.insert(bookmarks, bookmark.toMap());
  }

  Future<void> updateBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.update(
      bookmarks,
      bookmark.toMap(),
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete(bookmarks, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> urlExists(String url) async {
    final db = await database;
    final rows = await db.query(
      bookmarks,
      columns: ['id'],
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static int _colorFor(String name) {
    const palette = [
      0xFF6C7AE0, 0xFF2E9E6B, 0xFFE0663B, 0xFF9B5DE5,
      0xFF00A6A6, 0xFFD4508A, 0xFF3A86FF, 0xFFF2A33C,
    ];
    return palette[name.hashCode.abs() % palette.length];
  }
}
