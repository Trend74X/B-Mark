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
    required this.resultCount,
    required this.hasSearch,
    required this.onSelected,
    required this.onManage,
    this.vaultLocked = false,
  });

  final List<BookmarkCategory> categories;
  final int? selectedCategoryId;

  /// Per-category counts, already narrowed down to the current search results.
  final Map<int, int> counts;

  /// Total bookmarks across every category.
  final int totalCount;

  /// How many bookmarks match the current search, before the category filter.
  final int resultCount;

  /// Whether a search query is active.
  final bool hasSearch;

  /// Whether the protected Vault category still needs authentication.
  final bool vaultLocked;

  final ValueChanged<int?> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _chip(
            context,
            label: 'All',
            count: hasSearch ? resultCount : totalCount,
            showCount:
                hasSearch && selectedCategoryId == null && resultCount != totalCount,
            selected: selectedCategoryId == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map((category) {
            final count = counts[category.id] ?? 0;
            final locked = category.isVault && vaultLocked;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chip(
                context,
                label: category.name,
                count: count,
                // No count when the search has nothing for this category.
                showCount: !locked && count > 0,
                selected: selectedCategoryId == category.id,
                accent: Color(category.colorValue),
                avatarIcon: locked ? Icons.lock_outline_rounded : null,
                onTap: () => onSelected(category.id),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Manage'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
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
    IconData? avatarIcon,
  }) {
    final theme = Theme.of(context);
    final color = accent == null
        ? theme.colorScheme.primary
        : CategoryColors.readable(accent, theme.brightness);

    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: avatarIcon != null
        ? Icon(
          avatarIcon,
          size: 15,
          color: selected ? theme.colorScheme.onPrimary : color,
        )
        : CircleAvatar(
          radius: 4,
          backgroundColor: selected ? theme.colorScheme.onPrimary : color,
        ),
      label: Text(showCount ? '$label · $count' : label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurfaceVariant,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      selectedColor: theme.colorScheme.primary,
      side: BorderSide(
        color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
