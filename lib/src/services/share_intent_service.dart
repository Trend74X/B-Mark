import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class IncomingShare {
  final String rawText;
  final String url;
  final String? sourceApp;

  const IncomingShare({
    required this.rawText,
    required this.url,
    this.sourceApp,
  });
}

class ShareIntentService {
  ShareIntentService._();

  static final ShareIntentService instance = ShareIntentService._();

  static const _sourceChannel = MethodChannel('bmark/source');

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final _controller = StreamController<IncomingShare>.broadcast();

  Stream<IncomingShare> get stream => _controller.stream;

  static final _urlPattern =
      RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

  /// Pulls the first http(s) URL out of [text], tidying up stray punctuation
  /// and a missing scheme. Returns null when there is nothing usable.
  static String? extractUrl(String? text) {
    if (text == null) return null;

    var candidate = text.trim();
    if (candidate.isEmpty) return null;

    // People type "example.com" as often as a full link.
    if (!candidate.contains('://')) {
      candidate = 'https://$candidate';
    }

    final match = _urlPattern.firstMatch(candidate);
    final found = match?.group(0) ?? candidate;
    final cleaned = _cleanUrl(found);
    if (cleaned.isEmpty) return null;

    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return cleaned;
  }

  void start() {
    _subscription ??=
        ReceiveSharingIntent.instance.getMediaStream().listen(_handleFiles);

    ReceiveSharingIntent.instance.getInitialMedia().then(_handleFiles);
  }

  Future<void> _handleFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final raw = files.first.path;
    final match = _urlPattern.firstMatch(raw);
    if (match == null) return;

    final url = _cleanUrl(match.group(0)!);
    if (url.isEmpty) return;

    // Clear the launch intent so it is not replayed on the next start.
    unawaited(ReceiveSharingIntent.instance.reset());

    final share = IncomingShare(
      rawText: raw,
      url: url,
      sourceApp: await _resolveSource(),
    );

    if (!_controller.isClosed) _controller.add(share);
  }

  /// Asks the host platform which app sent the current share intent.
  Future<String?> _resolveSource() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final label =
          await _sourceChannel.invokeMethod<String>('getShareSource');
      return _isMeaningful(label) ? label!.trim() : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The system share sheet and adb report themselves as the sender. Those
  /// labels are noise, so we fall back to the link's host instead.
  static bool _isMeaningful(String? label) {
    if (label == null) return false;
    final value = label.trim().toLowerCase();
    if (value.isEmpty) return false;
    return !const {
      'shell',
      'android',
      'system ui',
      'systemui',
      'google play services',
      'adb',
    }.contains(value);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  /// Trims trailing punctuation that browsers/apps append to shared links.
  static String _cleanUrl(String url) {
    return url.replaceFirst(RegExp(r'[)\],.;:!?]+$'), '');
  }
}
