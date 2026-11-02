import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../models/bookmark_category.dart';
import '../utils/category_colors.dart';
import 'thumbnail_preview.dart';

class BookmarkCard extends StatelessWidget {
  const BookmarkCard({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onShare,
    required this.onRename,
    required this.onChangeCategory,
    required this.onDelete,
    this.category,
  });

  final Bookmark bookmark;
  final BookmarkCategory? category;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(bookmark.url)?.host.replaceFirst(
          RegExp(r'^www\.'),
          '',
        ) ??
        bookmark.url;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThumbnailPreview(
                url: bookmark.url,
                thumbnailUrl: bookmark.thumbnailUrl,
                size: 64,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.displayTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      host,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SourceChip(source: bookmark.source),
                        if (category != null) _CategoryChip(category: category!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 19),
                    tooltip: 'Share link',
                    onPressed: onShare,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 32,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Bookmark options',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                        case 'category':
                          onChangeCategory();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Edit name')),
                      PopupMenuItem(
                        value: 'category',
                        child: Text('Change category'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public_rounded,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              source,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final BookmarkCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        CategoryColors.readable(Color(category.colorValue), theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CategoryColors.surface(
          Color(category.colorValue),
          theme.brightness,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        category.name,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
