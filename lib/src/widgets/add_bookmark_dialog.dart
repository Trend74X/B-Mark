import 'package:flutter/material.dart';

import '../models/bookmark_category.dart';
import '../services/share_intent_service.dart';
import 'text_prompt_dialog.dart';
import 'thumbnail_preview.dart';

class AddBookmarkResult {
  final String title;
  final int? categoryId;
  final String? thumbnailUrl;

  const AddBookmarkResult({required this.title, this.categoryId, this.thumbnailUrl});
}

/// Shown before anything is persisted so the user can name the bookmark and
/// choose (or create) a category.
class AddBookmarkDialog extends StatefulWidget {
  final IncomingShare share;
  final String detectedTitle;
  final String? thumbnailUrl;
  final List<BookmarkCategory> categories;
  final String? suggestedCategoryName;
  final CreateCategory? onCreateCategory;

  /// Called when the user creates a category here, so the caller can keep its
  /// own list in step instead of relying on this dialog's local copy.
  final ValueChanged<BookmarkCategory>? onCategoryCreated;
  final bool metadataLoading;

  const AddBookmarkDialog({
    super.key,
    required this.share,
    required this.detectedTitle,
    required this.categories,
    this.thumbnailUrl,
    this.suggestedCategoryName,
    this.onCreateCategory,
    this.onCategoryCreated,
    this.metadataLoading = false,
  });

  @override
  State<AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<AddBookmarkDialog> {
  late final TextEditingController _titleController;
  int? _selectedCategoryId;

  /// Set once the user types, so late-arriving metadata never overwrites input.
  bool _titleEdited = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.detectedTitle)
      ..addListener(() {
        if (_titleController.text != widget.share.url) _titleEdited = true;
      });
    _selectedCategoryId = _initialCategoryId();
  }

  @override
  void didUpdateWidget(covariant AddBookmarkDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page title is fetched asynchronously, so it usually arrives after the
    // dialog is first shown. Apply it unless the user already typed a name.
    if (!_titleEdited && widget.detectedTitle != oldWidget.detectedTitle) {
      _titleController.text = widget.detectedTitle;
    }
  }

  int? _initialCategoryId() {
    final name = widget.suggestedCategoryName;
    if (name == null) return null;
    for (final category in widget.categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) {
        return category.id;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
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
    if (widget.onCreateCategory == null) return;

    final category = await widget.onCreateCategory!(trimmed);
    if (!mounted) return;
    setState(() {
      // Guard against a duplicate slipping in from a double tap.
      if (!widget.categories.any((c) => c.id == category.id)) {
        widget.categories.add(category);
      }
      _selectedCategoryId = category.id;
    });
    widget.onCategoryCreated?.call(category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No manual viewInsets padding here: Dialog already insets itself for the
    // keyboard, and adding it again pushed the dialog - and the top-right
    // "New" button - off the screen when the new-category field was focused.
    return AlertDialog(
      title: const Text('Save bookmark'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThumbnailPreview(
                    thumbnailUrl: widget.thumbnailUrl,
                    url: widget.share.url,
                    size: 64,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.share.sourceApp != null)
                          Row(
                            children: [
                              Icon(
                                Icons.travel_explore,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Shared from ${widget.share.sourceApp}',
                                  style: theme.textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          widget.share.url,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Tap to rename this bookmark',
                  suffixIcon: widget.metadataLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Category', style: theme.textTheme.titleSmall)),
                  TextButton.icon(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Uncategorised'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) => setState(() => _selectedCategoryId = null),
                  ),
                  ...widget.categories.map(
                    (category) => ChoiceChip(
                      label: Text(category.name),
                      selected: _selectedCategoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = category.id),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.bookmark_add),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    Navigator.of(context).pop(
      AddBookmarkResult(
        title: title.isEmpty ? widget.share.url : title,
        categoryId: _selectedCategoryId,
        thumbnailUrl: widget.thumbnailUrl,
      ),
    );
  }
}

typedef CreateCategory = Future<BookmarkCategory> Function(String name);
