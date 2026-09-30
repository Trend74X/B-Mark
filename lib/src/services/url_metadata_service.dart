import 'package:http/http.dart' as http;

class UrlMetadata {
  final String title;
  final String? thumbnailUrl;

  const UrlMetadata({this.title = '', this.thumbnailUrl});

  bool get hasTitle => title.trim().isNotEmpty;
}

class UrlMetadataService {
  UrlMetadataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Fetches the page title and social thumbnail for [url].
  /// Never throws - returns empty metadata when the page cannot be read.
  Future<UrlMetadata> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return const UrlMetadata();

    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return const UrlMetadata();
      }

      // The <head> is the cheap happy path, but huge pages (YouTube is ~1.3 MB)
      // can push the meta tags past it, so fall back to scanning everything.
      final body = response.body;
      final head =
          body.length > 200000 ? body.substring(0, 200000) : body;
      return _parse(head, body, uri);
    } catch (_) {
      return const UrlMetadata();
    }
  }

  UrlMetadata _parse(String head, String body, Uri pageUri) {
    var title = _meta(head, 'og:title') ??
        _meta(head, 'twitter:title') ??
        _titleTag(head) ??
        _meta(body, 'og:title') ??
        _meta(body, 'twitter:title') ??
        _titleTag(body);
    var image = _meta(head, 'og:image') ??
        _meta(head, 'twitter:image') ??
        _meta(body, 'og:image') ??
        _meta(body, 'twitter:image');

    title = _decodeEntities(title ?? '').trim();
    if (title.length > 160) title = '${title.substring(0, 157)}...';

    return UrlMetadata(
      title: title,
      thumbnailUrl: _absolute(image, head, pageUri),
    );
  }
  String? _meta(String html, String property) {
    final escaped = RegExp.escape(property);
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)\\s*=\\s*"$escaped"[^>]*content\\s*=\\s*"([^"]*)"',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content\\s*=\\s*"([^"]*)"[^>]*(?:property|name)\\s*=\\s*"$escaped"',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _titleTag(String html) =>
      RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true)
          .firstMatch(html)
          ?.group(1);

  /// Resolves a possibly relative thumbnail URL against the page.
  String? _absolute(String? value, String html, Uri pageUri) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:')) return null;

    final base = _baseTag(html) ?? pageUri;
    try {
      return base.resolve(raw).toString();
    } catch (_) {
      return null;
    }
  }

  Uri? _baseTag(String html) {
    final href = RegExp(r'<base[^>]+href\s*=\s*"([^"]+)"', caseSensitive: false)
        .firstMatch(html)
        ?.group(1);
    return href == null ? null : Uri.tryParse(href);
  }

  static String _decodeEntities(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  void dispose() => _client.close();
}

/// One-shot helper that owns and disposes its own client.
Future<UrlMetadata> fetchUrlMetadata(String url) async {
  final service = UrlMetadataService();
  try {
    return await service.fetch(url);
  } finally {
    service.dispose();
  }
}
