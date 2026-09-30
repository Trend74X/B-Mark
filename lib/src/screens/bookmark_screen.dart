import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../models/bookmark.dart';
import '../models/bookmark_category.dart';
import '../services/share_intent_service.dart';
import '../services/url_metadata_service.dart';
import '../widgets/add_bookmark_dialog.dart';
import '../widgets/bookmark_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bar.dart';
import '../widgets/manage_categories_dialog.dart';
import '../widgets/text_prompt_dialog.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final _database = AppDatabase.instance;
  List<Bookmark> _bookmarks = [];
  List<BookmarkCategory> _categories = [];

  /// `null` means "All" - the default filter.
  int? _selectedCategoryId;
  String _searchQuery = '';

  bool _loading = true;
  bool _handlingShare = false;
  StreamSubscription<IncomingShare>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _shareSubscription = ShareIntentService.instance.stream.listen(_onShare);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShareIntentService.instance.start();
      _load();
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ loading

  Future<void> _load() async {
    final results = await Future.wait([
      _database.fetchCategories(),
      _database.fetchBookmarks(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<BookmarkCategory>;
      _bookmarks = results[1] as List<Bookmark>;
      _loading = false;
    });
  }

  Future<void> _refreshBookmarks() async {
    final items = await _database.fetchBookmarks();
    if (!mounted) return;
    setState(() => _bookmarks = items);
  }

  // ------------------------------------------------------------------- sharing

  Future<void> _onShare(IncomingShare share) async {
    if (_handlingShare) return;
    _handlingShare = true;

    try {
      await _presentSaveDialog(share);
    } finally {
      _handlingShare = false;
    }
  }

  /// Shared by the share-sheet flow and manual entry.
  Future<void> _presentSaveDialog(IncomingShare share) async {
    if (await _database.urlExists(share.url)) {
      if (!mounted) return;
      _showSnack('Already saved: ${share.url}', isError: true);
      return;
    }

    if (!mounted) return;

    // Started once, outside the builder: a rebuild of the dialog must not
    // kick off a second network request.
    final metadataFuture = fetchUrlMetadata(share.url);

    // Open the dialog immediately, then fill in metadata as it arrives.
    final result = await showDialog<AddBookmarkResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FutureBuilder<UrlMetadata>(
        future: metadataFuture,
        builder: (context, snapshot) {
          final metadata = snapshot.data ?? const UrlMetadata();
          return AddBookmarkDialog(
            share: share,
            detectedTitle: metadata.hasTitle ? metadata.title : share.url,
            thumbnailUrl: metadata.thumbnailUrl,
            categories: List<BookmarkCategory>.of(_categories),
            suggestedCategoryName: _suggestCategory(share),
            onCreateCategory: (name) => _database.addCategory(name),
            onCategoryCreated: (category) => _rememberCategory(category),
            metadataLoading: snapshot.connectionState != ConnectionState.done,
          );
        },
      ),
    );

    if (result == null || !mounted) return;
    await _saveBookmark(share, result);
  }

  /// Adds a category to the in-memory list so chips and filters see it without
  /// waiting for a full reload.
  void _rememberCategory(BookmarkCategory category) {
    if (!mounted) return;
    setState(() {
      if (_categories.any((c) => c.id == category.id)) return;
      _categories.add(category);
    });
  }

  /// Lets the user type a link instead of sharing one.
  Future<void> _addManually() async {
    if (_handlingShare) return;
    _handlingShare = true;

    try {
      final typed = await showDialog<String>(
        context: context,
        builder: (context) => const TextPromptDialog(
          title: 'Add bookmark',
          label: 'Link',
          hintText: 'https://example.com/page',
          confirmLabel: 'Next',
          keyboardType: TextInputType.url,
        ),
      );

      if (typed == null || !mounted) return;

      final url = ShareIntentService.extractUrl(typed);
      if (url == null) {
        _showSnack('That does not look like a link', isError: true);
        return;
      }

      await _presentSaveDialog(
        IncomingShare(rawText: typed, url: url),
      );
    } finally {
      _handlingShare = false;
    }
  }

  /// Best-effort category guess from the source app, falling back to the host.
  String? _suggestCategory(IncomingShare share) {
    final source = share.sourceApp?.toLowerCase();
    if (source != null) {
      for (final category in _categories) {
        final name = category.name.toLowerCase();
        if (source.contains(name) || name.contains(source)) return category.name;
      }
    }

    final host = Uri.tryParse(share.url)?.host.toLowerCase() ?? '';
    for (final category in _categories) {
      final name = category.name.toLowerCase().replaceAll('twitter', 'x');
      if (name.isNotEmpty && host.contains(name)) return category.name;
    }
    return null;
  }

  // -------------------------------------------------------------------- actions

  Future<void> _saveBookmark(
    IncomingShare share,
    AddBookmarkResult result,
  ) async {
    await _database.insertBookmark(
      Bookmark(
        url: share.url,
        title: result.title,
        source: share.sourceApp ?? _hostName(share.url),
        categoryId: result.categoryId,
        thumbnailUrl: result.thumbnailUrl,
        createdAt: DateTime.now(),
      ),
    );
    await _load();
  }

  static String _hostName(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  Future<void> _openBookmark(Bookmark bookmark) async {
    final uri = Uri.tryParse(bookmark.url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showSnack('Could not open link', isError: true);
    }
  }

  Future<void> _renameBookmark(Bookmark bookmark) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Edit name',
        label: 'Name',
        initialText: bookmark.title.trim(),
        confirmLabel: 'Save',
        autofocus: true,
      ),
    );
    if (name == null || !mounted) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _database.updateBookmark(bookmark.copyWith(title: trimmed));
    await _refreshBookmarks();
  }

  Future<void> _changeCategory(Bookmark bookmark) async {
    // Wrapped in a holder so that "Uncategorised" (null) can be told apart
    // from the user dismissing the dialog (also null).
    final choice = await showDialog<_CategoryChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to category'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(const _CategoryChoice(null)),
            child: const Text('Uncategorised'),
          ),
          ..._categories.map(
            (category) => SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_CategoryChoice(category)),
              child: Text(category.name),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _database.updateBookmark(
      bookmark.copyWith(
        categoryId: choice.category?.id,
        clearCategory: choice.category == null,
      ),
    );
    await _refreshBookmarks();
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bookmark?'),
        content: Text(bookmark.displayTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || bookmark.id == null) return;
    await _database.deleteBookmark(bookmark.id!);
    await _refreshBookmarks();
  }

  Future<void> _manageCategories() async {
    await showDialog(
      context: context,
      builder: (context) => ManageCategoriesDialog(
        categories: _categories,
        onCreate: _database.addCategory,
        onDelete: _database.deleteCategory,
        onReorder: _database.reorderCategories,
      ),
    );
    await _load();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.errorContainer : null,
        ),
      );
  }

  // ---------------------------------------------------------------------- build

  /// Applies the active category filter and then the search query.
  ///
  /// [_bookmarks] always holds every row, so counts and totals stay correct
  /// no matter which filter is active.
  List<Bookmark> get _visibleBookmarks {
    final categoryId = _selectedCategoryId;
    final query = _searchQuery.trim().toLowerCase();

    return _bookmarks.where((bookmark) {
      if (categoryId != null && bookmark.categoryId != categoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      return bookmark.displayTitle.toLowerCase().contains(query) ||
          bookmark.url.toLowerCase().contains(query) ||
          bookmark.source.toLowerCase().contains(query);
    }).toList();
  }

  bool get _isFiltered => _selectedCategoryId != null || _searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleBookmarks;
    final total = _bookmarks.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bookmarks'),
            // Always visible, regardless of the active filter.
            Text(
              _isFiltered
                ? '${visible.length} of $total saved'
                : total == 1
                  ? '1 bookmark'
                  : '$total bookmarks',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage categories',
            onPressed: _manageCategories,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search bookmarks',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ),
              FilterBar(
                categories: _categories,
                selectedCategoryId: _selectedCategoryId,
                counts: _countByCategory(),
                totalCount: total,
                filteredCount: visible.length,
                onSelected: (id) => setState(() => _selectedCategoryId = id),
                onManage: _manageCategories,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManually,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? EmptyState(
                      filtered: _searchQuery.isNotEmpty ||
                          _selectedCategoryId != null,
                    )

              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bookmark = visible[index];
                    return BookmarkCard(
                      bookmark: bookmark,
                      category: _categoryFor(bookmark.categoryId),
                      onTap: () => _openBookmark(bookmark),
                      onRename: () => _renameBookmark(bookmark),
                      onChangeCategory: () => _changeCategory(bookmark),
                      onDelete: () => _deleteBookmark(bookmark),
                    );
                  },
                ),
    );
  }

  BookmarkCategory? _categoryFor(int? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Counts per category across *all* bookmarks, not just the filtered view.
  Map<int, int> _countByCategory() {
    final counts = <int, int>{};
    for (final bookmark in _bookmarks) {
      final id = bookmark.categoryId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}

/// Result of the "Move to category" dialog.
///
/// Wraps the chosen category so that clearing the category (`null`) is
/// distinct from dismissing the dialog.
class _CategoryChoice {
  const _CategoryChoice(this.category);

  final BookmarkCategory? category;
}
