import 'package:flutter/material.dart';

import '../models/bookmark_category.dart';
import '../utils/category_colors.dart';

/// Horizontal filter chips. "All" is always first and is the default selection.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.counts,
    required this.totalCount,
    required this.filteredCount,
    required this.onSelected,
    required this.onManage,
  });

  final List<BookmarkCategory> categories;
  final int? selectedCategoryId;
  final Map<int, int> counts;

  /// Total bookmarks across every category.
  final int totalCount;

  /// How many bookmarks the active filter currently shows.
  final int filteredCount;

  final ValueChanged<int?> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(
            context,
            label: 'All',
            count: totalCount,
            showCount: selectedCategoryId == null && filteredCount != totalCount,
            selected: selectedCategoryId == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map((category) {
            final count = counts[category.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chip(
                context,
                label: category.name,
                count: count,
                showCount: true,
                selected: selectedCategoryId == category.id,
                accent: Color(category.colorValue),
                onTap: () => onSelected(category.id),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              label: const Text('Manage'),
              onPressed: onManage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required int count,
    required bool showCount,
    required bool selected,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final color = accent == null
        ? theme.colorScheme.primary
        : CategoryColors.readable(accent, theme.brightness);

    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: CircleAvatar(radius: 5, backgroundColor: color),
      label: Text(showCount ? '$label${count == 0 ? '' : ' ($count)'}' : label),
      showCheckmark: false,
    );
  }
}
