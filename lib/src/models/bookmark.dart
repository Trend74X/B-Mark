class Bookmark {
  final int? id;
  final String url;
  final String title;
  final String source;
  final int? categoryId;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.url,
    required this.title,
    required this.source,
    this.categoryId,
    this.thumbnailUrl,
    required this.createdAt,
  });

  String get displayTitle =>
      title.trim().isEmpty ? url : title.trim();

  Bookmark copyWith({
    int? id,
    String? url,
    String? title,
    String? source,
    int? categoryId,
    String? thumbnailUrl,
    DateTime? createdAt,
    bool clearCategory = false,
  }) {
    return Bookmark(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      source: source ?? this.source,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'url': url,
        'title': title,
        'source': source,
        'category_id': categoryId,
        'thumbnail_url': thumbnailUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Bookmark.fromMap(Map<String, Object?> map) => Bookmark(
        id: map['id'] as int?,
        url: map['url'] as String? ?? '',
        title: map['title'] as String? ?? '',
        source: map['source'] as String? ?? 'Unknown',
        categoryId: map['category_id'] as int?,
        thumbnailUrl: map['thumbnail_url'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int? ?? 0,
        ),
      );
}
