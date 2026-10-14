class BookmarkCategory {
  /// The built-in category whose contents are gated behind device
  /// authentication (fingerprint / face / device credential).
  static const vaultName = 'Vault';

  final int? id;
  final String name;
  final int colorValue;
  final bool isDefault;

  /// Whether this is the protected Vault category.
  final bool isVault;

  /// User-defined position; lower sorts first.
  final int sortOrder;

  const BookmarkCategory({
    this.id,
    required this.name,
    this.colorValue = 0xFF6C7AE0,
    this.isDefault = false,
    this.isVault = false,
    this.sortOrder = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': colorValue,
        'is_default': isDefault ? 1 : 0,
        'is_vault': isVault ? 1 : 0,
        'sort_order': sortOrder,
      };

  BookmarkCategory copyWith({int? sortOrder, bool? isVault}) =>
      BookmarkCategory(
        id: id,
        name: name,
        colorValue: colorValue,
        isDefault: isDefault,
        isVault: isVault ?? this.isVault,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  factory BookmarkCategory.fromMap(Map<String, Object?> map) =>
      BookmarkCategory(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        colorValue: (map['color'] as num?)?.toInt() ?? 0xFF6C7AE0,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
        isVault: (map['is_vault'] as int? ?? 0) == 1,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
