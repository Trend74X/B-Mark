import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  late StreamSubscription _intentDataStreamSubscription;
  List<Map<String, String>> savedBookmarks = [];

  @override
  void initState() {
    super.initState();
    _setupShareIntentListeners();
  }

  void _setupShareIntentListeners() {
    // 1. Listen for shared text when the app is already open or in the background
    _intentDataStreamSubscription = 
      ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          // URLs are usually passed as the 'path' or 'value' in the first media file
          _processIncomingText(value.first.path); 
        }
      }, onError: (err) {
        debugPrint("Share Stream Error: $err");
      });

    // 2. Check for shared text if the app was completely closed and launched via a share
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processIncomingText(value.first.path);
        
        // Clear the intent so it doesn't fire again unnecessarily
        ReceiveSharingIntent.instance.reset(); 
      }
    });
  }

  void _processIncomingText(String sharedText) {
    // Regex to extract a URL from a sentence (e.g., "Watch this! https://tiktok.com/...")
    RegExp urlRegex = RegExp(r"(https?:\/\/[^\s]+)");
    var match = urlRegex.firstMatch(sharedText);
    
    if (match != null) {
      String url = match.group(0)!;
      String category = _categorizeUrl(url);
      
      setState(() {
        savedBookmarks.add({
          "url": url,
          "platform": category,
        });
      });
      
    }
  }

  String _categorizeUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains("tiktok.com")) return "TikTok";
    if (lowerUrl.contains("instagram.com")) return "Instagram";
    if (lowerUrl.contains("facebook.com") || lowerUrl.contains("fb.watch")) return "Facebook";
    if (lowerUrl.contains("youtube.com") || lowerUrl.contains("youtu.be")) return "YouTube";
    return "Other";
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookmarks")),
      body: savedBookmarks.isEmpty
          ? const Center(child: Text("Share a video to this app to see it here!"))
          : ListView.builder(
              itemCount: savedBookmarks.length,
              itemBuilder: (context, index) {
                final item = savedBookmarks[index];
                return ListTile(
                  title: Text(item["platform"]!),
                  subtitle: Text(item["url"]!),
                  leading: const Icon(Icons.bookmark),
                );
              },
            ),
    );
  }
}