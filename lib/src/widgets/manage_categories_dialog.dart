import 'package:flutter/material.dart';

import '../models/bookmark_category.dart';
import '../utils/category_colors.dart';
import 'text_prompt_dialog.dart';

/// Lets the user add, delete and reorder categories.
///
/// The order set here is the order the filter chips appear in.
class ManageCategoriesDialog extends StatefulWidget {
  final List<BookmarkCategory> categories;
  final Future<BookmarkCategory> Function(String) onCreate;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(List<int> orderedIds) onReorder;

  const ManageCategoriesDialog({
    super.key,
    required this.categories,
    required this.onCreate,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  late final List<BookmarkCategory> _categories = List.of(widget.categories);

Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const TextPromptDialog(
        title: 'New category',
        label: 'Category name',
        hintText: 'e.g. Recipes',
        confirmLabel: 'Add',
        textCapitalization: TextCapitalization.words,
      ),
    );

    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;

    final category = await widget.onCreate(trimmed);
    if (!mounted) return;
    setState(() {
      // Appended, not re-sorted: the user's ordering is respected.
      if (!_categories.any((c) => c.id == category.id)) {
        _categories.add(category);
      }
    });
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, moved);
    });

    final orderedIds = _categories
        .map((category) => category.id)
        .whereType<int>()
        .toList();
    if (orderedIds.isEmpty) return;
    await widget.onReorder(orderedIds);
  }

  Future<void> _delete(BookmarkCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Bookmarks in this category will become uncategorised.',
        ),
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

    if (confirmed != true || category.id == null || !mounted) return;
    await widget.onDelete(category.id!);
    if (!mounted) return;
    setState(() => _categories.removeWhere((c) => c.id == category.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage categories'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: _categories.isEmpty
            ? const Center(child: Text('No categories yet'))
            : ReorderableListView.builder(
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                itemCount: _categories.length,
                onReorder: _reorder,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Padding(
                    key: ValueKey(category.id ?? category.name),
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 8,
                        backgroundColor: CategoryColors.readable(
                          Color(category.colorValue),
                          Theme.of(context).brightness,
                        ),
                      ),
                      title: Text(category.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!category.isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(category),
                              tooltip: 'Delete',
                            ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add category'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_categories),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
